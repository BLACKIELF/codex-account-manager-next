// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::Arc;

use tauri::Manager;
use tracing::info;

mod app_state;
mod commands;
mod tray;

use app_state::AppState;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let app_data_dir = app.path().app_data_dir().map_err(|e| {
                eprintln!("Failed to resolve app data dir: {}", e);
                e
            })?;
            info!("App data dir: {}", app_data_dir.display());

            let state = Arc::new(AppState::new(app_data_dir));
            app.manage(state.clone());

            // Hide main window to tray on close instead of quitting.
            if let Some(window) = app.get_webview_window("main") {
                let window_clone = window.clone();
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                        tray::hide_to_tray(&window_clone);
                        api.prevent_close();
                    }
                });
            }

            tray::setup_tray(app.handle())?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::usage::get_local_usage,
            commands::usage::refresh_usage,
            commands::usage::clear_cache,
            commands::settings::get_settings,
            commands::settings::set_settings,
            commands::settings::open_settings_window,
            tray_show_main_window,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[tauri::command]
fn tray_show_main_window(app: tauri::AppHandle) {
    tray::show_main_window(&app);
}
