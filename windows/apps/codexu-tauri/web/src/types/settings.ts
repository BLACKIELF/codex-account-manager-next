export type ThemeMode = 'system' | 'light' | 'dark';
export type TrayDensity = 'minimal' | 'classic' | 'rich';
export type { InterfaceLanguage } from '../i18n/messages';
import type { InterfaceLanguage } from '../i18n/messages';
import type { PaletteId } from '../utils/paletteCatalog';
export type { PaletteId };

export interface AppConfig {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
  language: InterfaceLanguage;
  palette_id: PaletteId;
}

export interface SettingsResponse {
  codex_root: string;
  cache_dir: string;
  theme: ThemeMode;
  refresh_interval_secs: number;
  tray_density: TrayDensity;
  language: InterfaceLanguage;
  palette_id: PaletteId;
  app_data_dir: string;
}

export interface SettingsDto {
  config: AppConfig;
  app_data_dir: string;
}
