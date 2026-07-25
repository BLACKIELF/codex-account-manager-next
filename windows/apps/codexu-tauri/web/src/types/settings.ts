export type ThemeMode = 'system' | 'light' | 'dark';
export type TrayDensity = 'minimal' | 'classic' | 'rich';

export interface AppConfig {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
}

export interface SettingsResponse {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
  app_data_dir: string;
}

export interface SettingsDto {
  config: AppConfig;
  app_data_dir: string;
}
