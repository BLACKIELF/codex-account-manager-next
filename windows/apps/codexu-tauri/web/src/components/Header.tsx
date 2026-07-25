import { RefreshCw, Settings, Sun, Moon, Monitor } from 'lucide-react';
import { invoke } from '@tauri-apps/api/core';
import { isTauriRuntimeAvailable } from '../utils/tauri';
import type { ThemeMode } from '../types/settings';

interface HeaderProps {
  lastUpdated: number | null;
  theme: ThemeMode;
  onThemeChange: (theme: ThemeMode) => void;
  onRefresh: () => void;
  refreshing: boolean;
}

export function Header({
  lastUpdated,
  theme,
  onThemeChange,
  onRefresh,
  refreshing,
}: HeaderProps) {
  const openSettings = async () => {
    if (!isTauriRuntimeAvailable()) {
      return;
    }

    try {
      await invoke('open_settings_window');
    } catch (error) {
      console.error('Failed to open settings window:', error);
    }
  };

  return (
    <header className="mx-4 mt-4 glass-toolbar px-5 py-3 rounded-2xl flex items-center justify-between">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-xl glass-button-solid flex items-center justify-center overflow-hidden">
          <img
            src="/icons/icon.png"
            alt="codexU icon"
            className="w-full h-full object-contain"
          />
        </div>
        <div>
          <h1 className="text-lg font-semibold text-primary leading-tight">codexU</h1>
          {lastUpdated && (
            <p className="text-xs text-tertiary">
              Updated {new Date(lastUpdated).toLocaleTimeString()}
            </p>
          )}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <div className="flex items-center glass-toolbar rounded-full p-0.5">
          <button
            onClick={() => onThemeChange('light')}
            className={`p-1.5 rounded-full transition-all ${
              theme === 'light'
                ? 'glass-button-solid'
                : 'text-secondary glass-button'
            }`}
            title="Light"
          >
            <Sun size={14} />
          </button>
          <button
            onClick={() => onThemeChange('dark')}
            className={`p-1.5 rounded-full transition-all ${
              theme === 'dark' ? 'glass-button-solid' : 'text-secondary glass-button'
            }`}
            title="Dark"
          >
            <Moon size={14} />
          </button>
          <button
            onClick={() => onThemeChange('system')}
            className={`p-1.5 rounded-full transition-all ${
              theme === 'system'
                ? 'glass-button-solid'
                : 'text-secondary glass-button'
            }`}
            title="System"
          >
            <Monitor size={14} />
          </button>
        </div>

        <button
          onClick={onRefresh}
          disabled={refreshing}
          className="p-2 rounded-full glass-button text-secondary hover:text-primary transition-colors disabled:opacity-50"
          title="Refresh"
        >
          <RefreshCw size={16} className={refreshing ? 'animate-spin' : ''} />
        </button>

        <button
          onClick={openSettings}
          className="p-2 rounded-full glass-button-solid"
          title="Settings"
        >
          <Settings size={16} />
        </button>
      </div>
    </header>
  );
}
