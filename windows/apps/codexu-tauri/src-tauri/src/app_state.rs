use std::path::{Path, PathBuf};
use std::sync::Arc;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tokio::sync::{Mutex, RwLock};
use tracing::{error, info, warn};

use codexu_core::models::CodexDashboardSnapshot;
use codexu_core::readers::CodexDashboardProvider;

/// User-configurable app settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    /// Path to Codex data root (e.g. ~/.codex).
    pub codex_root: PathBuf,
    /// Path to codexU cache directory.
    pub cache_dir: PathBuf,
    /// Theme preference.
    #[serde(default)]
    pub theme: ThemeMode,
    /// Auto-refresh interval in seconds.
    #[serde(default = "default_refresh_interval_secs")]
    pub refresh_interval_secs: u64,
    /// Tray density mode (stored for future use).
    #[serde(default)]
    pub tray_density: TrayDensity,
}

impl Default for AppConfig {
    fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
        Self {
            codex_root: home.join(".codex"),
            cache_dir: dirs::cache_dir()
                .unwrap_or_else(|| home.join(".cache"))
                .join("codexU"),
            theme: ThemeMode::System,
            refresh_interval_secs: default_refresh_interval_secs(),
            tray_density: TrayDensity::Classic,
        }
    }
}

fn default_refresh_interval_secs() -> u64 {
    60
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemeMode {
    #[default]
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrayDensity {
    Minimal,
    #[default]
    Classic,
    Rich,
}

impl AppConfig {
    pub fn load(app_data_dir: &Path) -> Self {
        let path = app_data_dir.join("settings.json");
        match std::fs::read_to_string(&path) {
            Ok(text) => match serde_json::from_str::<AppConfig>(&text) {
                Ok(c) => c,
                Err(e) => {
                    warn!("Failed to parse settings file, using defaults: {}", e);
                    Self::default()
                }
            },
            Err(_) => Self::default(),
        }
    }

    pub fn save(&self, app_data_dir: &Path) -> anyhow::Result<()> {
        std::fs::create_dir_all(app_data_dir)?;
        let path = app_data_dir.join("settings.json");
        let text = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, text)?;
        Ok(())
    }
}

/// Cached usage snapshot plus metadata.
#[derive(Debug, Clone)]
pub struct CachedSnapshot {
    pub usage: CodexDashboardSnapshot,
    pub refreshed_at: DateTime<Utc>,
}

/// Shared application state.
pub struct AppState {
    pub config: RwLock<AppConfig>,
    pub snapshot: RwLock<Option<CachedSnapshot>>,
    pub refresh_lock: Mutex<()>,
    pub app_data_dir: PathBuf,
}

impl AppState {
    pub fn new(app_data_dir: PathBuf) -> Self {
        let config = AppConfig::load(&app_data_dir);
        Self {
            config: RwLock::new(config),
            snapshot: RwLock::new(None),
            refresh_lock: Mutex::new(()),
            app_data_dir,
        }
    }

    /// Get the cached usage, refreshing if the cache is missing or older than `max_age_secs`.
    pub async fn get_usage(
        self: &Arc<Self>,
        max_age_secs: u64,
    ) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        {
            let snapshot = self.snapshot.read().await;
            if let Some(ref s) = *snapshot {
                let age_secs = (Utc::now() - s.refreshed_at).num_seconds().max(0) as u64;
                if age_secs < max_age_secs {
                    return Ok(Some(s.usage.clone()));
                }
            }
        }
        self.refresh_usage().await
    }

    /// Force a refresh of the usage snapshot.
    pub async fn refresh_usage(self: &Arc<Self>) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        let _guard = self.refresh_lock.lock().await;
        info!("Refreshing usage snapshot");

        let config = self.config.read().await.clone();
        let provider = CodexDashboardProvider::new(&config.codex_root, &config.cache_dir);
        let now = Utc::now();
        let snapshot = provider.load_dashboard_snapshot(now).await?;

        let snapshot = snapshot.map(|snapshot| CachedSnapshot {
            usage: snapshot,
            refreshed_at: now,
        });
        let cached_usage = snapshot.as_ref().map(|snapshot| snapshot.usage.clone());

        {
            let mut guard = self.snapshot.write().await;
            *guard = snapshot;
        }

        if cached_usage.is_some() {
            info!("Usage snapshot refreshed");
        } else {
            warn!("No Codex usage data found");
        }
        Ok(cached_usage)
    }

    /// Update config and persist to disk.
    pub async fn update_config<F>(self: &Arc<Self>, f: F) -> anyhow::Result<AppConfig>
    where
        F: FnOnce(&mut AppConfig),
    {
        let mut config = self.config.write().await;
        f(&mut config);
        let cloned = config.clone();
        drop(config);
        cloned.save(&self.app_data_dir)?;
        Ok(cloned)
    }
}

/// Clears the codexU file cache for the configured cache directory.
pub async fn clear_cache(state: &Arc<AppState>) {
    let cache_dir = {
        let config = state.config.read().await;
        config.cache_dir.clone()
    };
    let codex_cache = cache_dir.join("codex").join("session-usage-v1.json");
    let claude_cache = cache_dir.join("claude-code").join("session-usage-v1.json");
    for path in [codex_cache, claude_cache] {
        if let Err(e) = tokio::fs::remove_file(&path).await {
            if e.kind() != std::io::ErrorKind::NotFound {
                error!("Failed to remove cache file {}: {}", path.display(), e);
            }
        }
    }
    {
        let mut guard = state.snapshot.write().await;
        *guard = None;
    }
    info!("Cleared codexU cache");
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    use chrono::Duration;
    use codexu_core::models::{
        AccountInfo, CodexDashboardSnapshot, CodexLeadershipSignal, LeadershipDashboardSnapshot,
        RuntimeMenuStatus, RuntimeScope, RuntimeUsageSnapshot, UsageSnapshot,
    };

    fn unique_temp_path(prefix: &str) -> PathBuf {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or_default();
        std::env::temp_dir().join(format!("{}-{}", prefix, stamp))
    }

    fn create_snapshot(now: DateTime<Utc>) -> CodexDashboardSnapshot {
        CodexDashboardSnapshot {
            codex: RuntimeUsageSnapshot {
                scope: RuntimeScope::Codex,
                snapshot: UsageSnapshot {
                    refreshed_at: now,
                    account: AccountInfo {
                        r#type: "codex-local".to_string(),
                        plan_type: None,
                        email_present: false,
                    },
                    limit_id: "codex-local".to_string(),
                    limit_name: "Codex local".to_string(),
                    quota_read_succeeded: false,
                    five_hour_quota: None,
                    seven_day_quota: None,
                    monthly_quota: None,
                    local: None,
                    task_board: None,
                    messages: vec![],
                },
                status: RuntimeMenuStatus::LocalOnly,
                quota_source_label: "Official quota unavailable on Windows".to_string(),
                usage_source_label: "Local Codex transcript data".to_string(),
            },
            leadership: CodexLeadershipSignal {
                score: None,
                evidence_coverage: 0.0,
                active_day_count: 0,
                period: "twentyEightDays".to_string(),
                model_version: "1.3-codex-interval".to_string(),
                report: Some(LeadershipDashboardSnapshot {
                    model_version: "1.3-codex-interval".to_string(),
                    refreshed_at: now,
                    reports: vec![],
                }),
            },
            refreshed_at: now,
            messages: vec!["Cached dashboard snapshot".to_string()],
        }
    }

    #[tokio::test]
    async fn get_usage_uses_cached_snapshot_before_ttl() {
        let app_data_dir = unique_temp_path("codexu-tauri-cache-test");
        let state = Arc::new(AppState::new(app_data_dir));
        let now = Utc::now();

        {
            let mut snapshot = state.snapshot.write().await;
            *snapshot = Some(CachedSnapshot {
                usage: create_snapshot(now - Duration::seconds(5)),
                refreshed_at: now,
            });
        }

        let value = state.get_usage(60).await.unwrap().unwrap();
        assert_eq!(value.messages, vec!["Cached dashboard snapshot".to_string()]);
        assert_eq!(value.refreshed_at, now - Duration::seconds(5));
    }

    #[tokio::test]
    async fn refresh_usage_caches_none_when_no_local_data() {
        let app_data_dir = unique_temp_path("codexu-tauri-refresh-none");
        let state = Arc::new(AppState::new(app_data_dir));
        let codex_root = unique_temp_path("codexu-tauri-codex-root-none");
        let cache_dir = unique_temp_path("codexu-tauri-cache-root-none");
        std::fs::create_dir_all(&cache_dir).unwrap();
        {
            let mut config = state.config.write().await;
            config.codex_root = codex_root;
            config.cache_dir = cache_dir;
        }

        let snapshot = state.refresh_usage().await.unwrap();
        assert!(snapshot.is_none());
        assert!(state.snapshot.read().await.is_none());
    }
}
