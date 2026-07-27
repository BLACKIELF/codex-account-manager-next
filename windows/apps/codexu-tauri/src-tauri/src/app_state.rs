use std::path::{Path, PathBuf};
use std::sync::Arc;
#[cfg(test)]
use std::sync::atomic::{AtomicUsize, Ordering};

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

#[derive(Debug, Clone, Eq, PartialEq)]
pub(crate) struct DashboardSourceKey {
    codex_root: PathBuf,
    cache_dir: PathBuf,
}

impl DashboardSourceKey {
    fn from_config(config: &AppConfig) -> Self {
        Self {
            codex_root: config.codex_root.clone(),
            cache_dir: config.cache_dir.clone(),
        }
    }
}

/// Cached usage snapshot plus metadata.
#[derive(Debug, Clone)]
pub struct CachedSnapshot {
    pub usage: Option<CodexDashboardSnapshot>,
    pub refreshed_at: DateTime<Utc>,
    pub source_key: DashboardSourceKey,
}

/// Shared application state.
pub struct AppState {
    pub config: RwLock<AppConfig>,
    pub snapshot: RwLock<Option<CachedSnapshot>>,
    pub refresh_lock: Mutex<()>,
    pub app_data_dir: PathBuf,
    #[cfg(test)]
    pub(crate) refresh_call_count: Arc<AtomicUsize>,
}

impl AppState {
    pub fn new(app_data_dir: PathBuf) -> Self {
        let config = AppConfig::load(&app_data_dir);
        Self {
            config: RwLock::new(config),
            snapshot: RwLock::new(None),
            refresh_lock: Mutex::new(()),
            app_data_dir,
            #[cfg(test)]
            refresh_call_count: Arc::new(AtomicUsize::new(0)),
        }
    }

    async fn current_source_key(&self) -> DashboardSourceKey {
        let config = self.config.read().await;
        DashboardSourceKey::from_config(&config)
    }

    fn is_fresh(snapshot: &CachedSnapshot, max_age_secs: u64) -> bool {
        let age_secs = (Utc::now() - snapshot.refreshed_at).num_seconds().max(0) as u64;
        age_secs < max_age_secs
    }

    /// Get the cached usage, refreshing if the cache is missing or older than `max_age_secs`.
    pub async fn get_usage(
        self: &Arc<Self>,
        max_age_secs: u64,
    ) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        let current_source = self.current_source_key().await;

        {
            let snapshot = self.snapshot.read().await;
            if let Some(ref cached) = *snapshot {
                if cached.source_key == current_source && Self::is_fresh(cached, max_age_secs) {
                    return Ok(cached.usage.clone());
                }
            }
        }

        let _guard = self.refresh_lock.lock().await;
        let current_source = self.current_source_key().await;

        {
            let snapshot = self.snapshot.read().await;
            if let Some(ref cached) = *snapshot {
                if cached.source_key == current_source && Self::is_fresh(cached, max_age_secs) {
                    return Ok(cached.usage.clone());
                }
            }
        }

        self.refresh_usage_from_source(current_source).await
    }

    /// Force a refresh of the usage snapshot.
    pub async fn refresh_usage(self: &Arc<Self>) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        let _guard = self.refresh_lock.lock().await;
        let source = self.current_source_key().await;
        self.refresh_usage_from_source(source).await
    }

    async fn refresh_usage_from_source(
        self: &Arc<Self>,
        source: DashboardSourceKey,
    ) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        let mut source = source;
        let mut latest_snapshot: Option<CodexDashboardSnapshot> = None;

        for _ in 0..2 {
            let provider = CodexDashboardProvider::new(&source.codex_root, &source.cache_dir);
            let now = Utc::now();
            let snapshot = provider.load_dashboard_snapshot(now).await?;
            latest_snapshot = snapshot.clone();

            #[cfg(test)]
            self.refresh_call_count.fetch_add(1, Ordering::SeqCst);

            let cache = Some(CachedSnapshot {
                usage: snapshot.clone(),
                refreshed_at: now,
                source_key: source.clone(),
            });
            {
                let mut guard = self.snapshot.write().await;
                let config = self.config.read().await;
                if DashboardSourceKey::from_config(&config) == source {
                    *guard = cache;
                    if snapshot.is_some() {
                        info!("Usage snapshot refreshed");
                    } else {
                        warn!("No Codex usage data found");
                    }
                    return Ok(snapshot);
                }
            }

            warn!(
                "Config source changed while refreshing dashboard snapshot; retrying with latest config"
            );

            let latest_source = {
                let config = self.config.read().await;
                DashboardSourceKey::from_config(&config)
            };
            source = latest_source;
        }

        warn!("Could not refresh usage snapshot with stable source config");
        Ok(latest_snapshot)
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
            let source = {
                let config = state.config.read().await;
                DashboardSourceKey::from_config(&config)
            };
            *snapshot = Some(CachedSnapshot {
                usage: Some(create_snapshot(now - Duration::seconds(5))),
                refreshed_at: now,
                source_key: source,
            });
        }

        let value = state.get_usage(60).await.unwrap().unwrap();
        assert_eq!(value.messages, vec!["Cached dashboard snapshot".to_string()]);
        assert_eq!(value.refreshed_at, now - Duration::seconds(5));
    }

    #[tokio::test]
    async fn get_usage_uses_cached_none_and_respects_ttl() {
        let app_data_dir = unique_temp_path("codexu-tauri-cache-none-ttl");
        let state = Arc::new(AppState::new(app_data_dir));
        let now = Utc::now();
        {
            let mut snapshot = state.snapshot.write().await;
            let source = {
                let config = state.config.read().await;
                DashboardSourceKey::from_config(&config)
            };
            *snapshot = Some(CachedSnapshot {
                usage: None,
                refreshed_at: now,
                source_key: source,
            });
        }

        let value = state.get_usage(120).await.unwrap();
        assert!(value.is_none());
        assert_eq!(0, state.refresh_call_count.load(Ordering::SeqCst));
    }

    #[tokio::test]
    async fn refresh_usage_stores_none_snapshot_and_keeps_ttl_entry() {
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

        let cached = state.snapshot.read().await.clone();
        assert!(cached.is_some());
        assert!(cached.unwrap().usage.is_none());
    }

    #[tokio::test]
    async fn get_usage_uses_latest_source_when_cached_source_is_stale() {
        let app_data_dir = unique_temp_path("codexu-tauri-source-change");
        let state = Arc::new(AppState::new(app_data_dir));
        let old_root = unique_temp_path("codexu-tauri-old-root");
        let new_root = unique_temp_path("codexu-tauri-new-root");
        let cache_dir = unique_temp_path("codexu-tauri-source-cache");
        std::fs::create_dir_all(&old_root).unwrap();
        std::fs::create_dir_all(&new_root).unwrap();
        std::fs::create_dir_all(&cache_dir).unwrap();
        std::fs::create_dir_all(old_root.join("archived_sessions")).unwrap();
        std::fs::create_dir_all(new_root.join("archived_sessions")).unwrap();
        {
            let mut config = state.config.write().await;
            config.codex_root = old_root.clone();
            config.cache_dir = cache_dir.clone();
        }
        {
            let mut snapshot = state.snapshot.write().await;
            *snapshot = Some(CachedSnapshot {
                usage: None,
                refreshed_at: Utc::now() - Duration::seconds(120),
                source_key: DashboardSourceKey::from_config(&AppConfig {
                    codex_root: old_root.clone(),
                    cache_dir: cache_dir.clone(),
                    theme: ThemeMode::System,
                    refresh_interval_secs: 60,
                    tray_density: TrayDensity::Classic,
                }),
            });
        }

        {
            let mut config = state.config.write().await;
            config.codex_root = new_root.clone();
        }

        let _ = state.get_usage(0).await.unwrap();

        let cached = state.snapshot.read().await.clone().expect("cache exists");
        assert_eq!(cached.source_key.codex_root, new_root);
    }

    #[tokio::test]
    async fn get_usage_only_refreshes_once_for_concurrent_readers() {
        let app_data_dir = unique_temp_path("codexu-tauri-single-flight");
        let state = Arc::new(AppState::new(app_data_dir));
        {
            let mut snapshot = state.snapshot.write().await;
            let source = {
                let config = state.config.read().await;
                DashboardSourceKey::from_config(&config)
            };
            *snapshot = Some(CachedSnapshot {
                usage: None,
                refreshed_at: Utc::now() - Duration::seconds(120),
                source_key: source,
            });
        }
        {
            let mut config = state.config.write().await;
            config.codex_root = unique_temp_path("codexu-tauri-single-flight-root");
            let cache_dir = unique_temp_path("codexu-tauri-single-flight-cache");
            std::fs::create_dir_all(&config.codex_root.join("archived_sessions")).unwrap();
            std::fs::create_dir_all(&cache_dir).unwrap();
            config.cache_dir = cache_dir;
        }

        let mut handles = Vec::new();
        for _ in 0..4 {
            let state = state.clone();
            handles.push(tokio::spawn(async move { state.get_usage(60).await }));
        }

        for handle in handles {
            handle.await.unwrap().unwrap();
        }

        let value = state.get_usage(60).await.unwrap();
        assert!(value.is_none());
        assert_eq!(1, state.refresh_call_count.load(Ordering::SeqCst));
    }
}
