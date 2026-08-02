export type ThemeMode = 'system' | 'light' | 'dark';
export type TrayDensity = 'minimal' | 'classic' | 'rich';
export type { InterfaceLanguage } from '../i18n/messages';
import type { InterfaceLanguage } from '../i18n/messages';

export interface AppConfig {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
  language: InterfaceLanguage;
}

export interface SettingsResponse {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
  language: InterfaceLanguage;
  app_data_dir: string;
}

export interface SettingsDto {
  config: AppConfig;
  app_data_dir: string;
}
