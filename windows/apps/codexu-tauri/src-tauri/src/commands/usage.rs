use tauri::{AppHandle, Emitter, Manager, State};

use crate::app_state::AppState;

#[tauri::command]
pub async fn get_local_usage(state: State<'_, std::sync::Arc<AppState>) -> Result<Option<codexu_core::models::LocalUsage>, String> {
    let config = state.config.read().await;
    let max_age = config.refresh_interval_secs;
    drop(config);
    state
        .get_usage(max_age)
        .await
        .map_err(|e| format!("Failed to load usage: {}", e))
}

#[tauri::command]
pub async fn refresh_usage(
    app: AppHandle,
    state: State<'_, std::sync::Arc<AppState>,
) -> Result<Option<codexu_core::models::LocalUsage>, String> {
    let usage = state
        .refresh_usage()
        .await
        .map_err(|e| format!("Failed to refresh usage: {}", e))?;
    let _ = app.emit("usage:updated", ());
    Ok(usage)
}

#[tauri::command]
pub async fn clear_cache(state: State<'_, std::sync::Arc<AppState>) -> Result<(), String> {
    crate::app_state::clear_cache(&state).await;
    Ok(())
}
