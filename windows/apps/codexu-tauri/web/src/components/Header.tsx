import { RefreshCw, Settings, Sun, Moon, Monitor } from 'lucide-react';
import { invoke } from '@tauri-apps/api/core';
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
    await invoke('open_settings_window');
  };

  return (
    <header className="flex items-center justify-between px-6 py-4 border-b border-theme bg-surface-elevated">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center text-white font-bold">
          cU
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
        <div className="flex items-center bg-surface-inset rounded-lg p-0.5 border border-theme">
          <button
            onClick={() => onThemeChange('light')}
            className={`p-1.5 rounded-md transition-colors ${
              theme === 'light' ? 'bg-surface text-primary shadow-sm' : 'text-secondary'
            }`}
            title="Light"
          >
            <Sun size={14} />
          </button>
          <button
            onClick={() => onThemeChange('dark')}
            className={`p-1.5 rounded-md transition-colors ${
              theme === 'dark' ? 'bg-surface text-primary shadow-sm' : 'text-secondary'
            }`}
            title="Dark"
          >
            <Moon size={14} />
          </button>
          <button
            onClick={() => onThemeChange('system')}
            className={`p-1.5 rounded-md transition-colors ${
              theme === 'system' ? 'bg-surface text-primary shadow-sm' : 'text-secondary'
            }`}
            title="System"
          >
            <Monitor size={14} />
          </button>
        </div>

        <button
          onClick={onRefresh}
          disabled={refreshing}
          className="p-2 rounded-lg bg-surface-inset text-secondary hover:text-primary border border-theme transition-colors disabled:opacity-50"
          title="Refresh"
        >
          <RefreshCw size={16} className={refreshing ? 'animate-spin' : ''} />
        </button>

        <button
          onClick={openSettings}
          className="p-2 rounded-lg bg-accent text-white hover:opacity-90 transition-opacity"
          title="Settings"
        >
          <Settings size={16} />
        </button>
      </div>
    </header>
  );
}
