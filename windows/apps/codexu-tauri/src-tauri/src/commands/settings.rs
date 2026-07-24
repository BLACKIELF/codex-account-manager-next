use std::path::PathBuf;

use tauri::{AppHandle, Emitter, Manager, State};

use crate::app_state::{AppConfig, AppState, ThemeMode, TrayDensity};

#[derive(Debug, serde::Serialize)]
pub struct SettingsDto {
    #[serde(flatten)]
    pub config: AppConfig,
    pub app_data_dir: PathBuf,
}

#[tauri::command]
pub async fn open_settings_window(app: AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("settings") {
        let _ = window.show();
        let _ = window.set_focus();
        return Ok(());
    }

    let window = tauri::WebviewWindowBuilder::new(
        &app,
        "settings",
        tauri::WebviewUrl::App("/".into()),
    )
    .title("Settings — codexU")
    .inner_size(540.0, 680.0)
    .resizable(false)
    .maximizable(false)
    .minimizable(false)
    .center()
    .build()
    .map_err(|e| format!("Failed to create settings window: {}", e))?;

    apply_theme(&app, app.state::<std::sync::Arc<AppState>>().config.blocking_read().theme);
    let _ = window.show();
    Ok(())
}

#[tauri::command]
pub async fn get_settings(
    state: State<'_, std::sync::Arc<AppState>>,
) -> Result<SettingsDto, String> {
    let config = state.config.read().await.clone();
    Ok(SettingsDto {
        config,
        app_data_dir: state.app_data_dir.clone(),
    })
}

#[derive(Debug, serde::Deserialize)]
pub struct UpdateSettingsRequest {
    pub codex_root: Option<PathBuf>,
    pub cache_dir: Option<PathBuf>,
    pub theme: Option<ThemeMode>,
    pub refresh_interval_secs: Option<u64>,
    pub tray_density: Option<TrayDensity>,
}

#[tauri::command]
pub async fn set_settings(
    app: AppHandle,
    state: State<'_, std::sync::Arc<AppState>>,
    req: UpdateSettingsRequest,
) -> Result<AppConfig, String> {
    let config = state
        .update_config(|config| {
            if let Some(path) = req.codex_root {
                config.codex_root = path;
            }
            if let Some(path) = req.cache_dir {
                config.cache_dir = path;
            }
            if let Some(theme) = req.theme {
                config.theme = theme;
            }
            if let Some(interval) = req.refresh_interval_secs {
                config.refresh_interval_secs = interval.clamp(10, 3600);
            }
            if let Some(density) = req.tray_density {
                config.tray_density = density;
            }
        })
        .await
        .map_err(|e| format!("Failed to save settings: {}", e))?;

    apply_theme(&app, config.theme);
    let _ = app.emit("settings:changed", config.clone());
    Ok(config)
}

fn apply_theme(app: &AppHandle, theme: ThemeMode) {
    let windows = app.webview_windows();
    let dark = match theme {
        ThemeMode::System => {
            // Frontend will detect system preference on load.
            return;
        }
        ThemeMode::Light => false,
        ThemeMode::Dark => true,
    };
    for (_, window) in windows {
        let _ = window.eval(&format!(
            "document.documentElement.classList.remove('dark'); if ({}) document.documentElement.classList.add('dark');",
            dark
        ));
        let _ = window.eval(&format!(
            "window.__CODEXU_THEME__ = '{}'",
            if dark { "dark" } else { "light" }
        ));
    }
}
