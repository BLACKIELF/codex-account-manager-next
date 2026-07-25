use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tokio::sync::{Mutex, RwLock};
use tracing::{error, info, warn};

use codexu_core::models::LocalUsage;
use codexu_core::readers::{CodexStateReader, CodexThreadMetadata, CodexTranscriptReader};

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
    pub usage: LocalUsage,
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
    ) -> anyhow::Result<Option<LocalUsage>> {
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
    pub async fn refresh_usage(self: &Arc<Self>) -> anyhow::Result<Option<LocalUsage>> {
        let _guard = self.refresh_lock.lock().await;
        info!("Refreshing usage snapshot");

        let config = self.config.read().await.clone();
        let state_db_path = config.codex_root.join("state_5.sqlite");

        let metadata: HashMap<String, CodexThreadMetadata> =
            if tokio::fs::try_exists(&state_db_path).await.unwrap_or(false) {
                match CodexStateReader::new(&state_db_path).load_metadata().await {
                    Ok(m) => {
                        info!("Loaded metadata for {} threads from state DB", m.len());
                        m
                    }
                    Err(e) => {
                        warn!("Failed to load Codex state metadata: {}", e);
                        HashMap::new()
                    }
                }
            } else {
                info!("Codex state DB not found; continuing without metadata enrichment");
                HashMap::new()
            };

        let reader = CodexTranscriptReader::new(&config.cache_dir);
        let usage = reader
            .load_local_usage_with_metadata(&config.codex_root, metadata, Utc::now())
            .await?;

        let snapshot = usage.clone().map(|u| CachedSnapshot {
            usage: u,
            refreshed_at: Utc::now(),
        });

        {
            let mut guard = self.snapshot.write().await;
            *guard = snapshot;
        }

        if usage.is_some() {
            info!("Usage snapshot refreshed");
        } else {
            warn!("No Codex usage data found");
        }
        Ok(usage)
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
