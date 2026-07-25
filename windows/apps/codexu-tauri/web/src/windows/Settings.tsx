import { useEffect, useState } from 'react';
import { open } from '@tauri-apps/plugin-dialog';
import { FolderOpen, RefreshCw, Trash2 } from 'lucide-react';
import { invoke } from '@tauri-apps/api/core';
import { useSettings } from '../hooks/useSettings';
import type { ThemeMode, TrayDensity } from '../types/settings';
import { isTauriRuntimeAvailable, requireTauriRuntime } from '../utils/tauri';

export function Settings() {
  const canInvokeTauri = isTauriRuntimeAvailable();
  const { settings, update, error } = useSettings();
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    applyTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

  if (!settings) {
    if (error) {
      return (
        <div className="h-full flex flex-col">
          <header className="mx-4 mt-4 glass-toolbar px-5 py-3 rounded-2xl">
            <h1 className="text-lg font-semibold text-primary">Settings</h1>
          </header>
          <div className="flex-1 p-6">
            <div className="glass-panel p-4 text-sm text-status-error">Failed to load settings: {error}</div>
          </div>
        </div>
      );
    }

    return (
      <div className="h-full flex items-center justify-center bg-transparent">
        <div className="glass-panel px-6 py-8 text-sm text-secondary">Loading settings...</div>
      </div>
    );
  }

  const config = settings.config;

  const pickDirectory = async (key: 'codex_root' | 'cache_dir') => {
    if (!canInvokeTauri) {
      return;
    }

    const selected = await open({ directory: true });
    if (selected) {
      await update({ [key]: selected });
      flashSaved();
    }
  };

  const handleTheme = async (theme: ThemeMode) => {
    if (!canInvokeTauri) {
      return;
    }

    await update({ theme });
    applyTheme(theme);
    flashSaved();
  };

  const handleDensity = async (tray_density: TrayDensity) => {
    if (!canInvokeTauri) {
      return;
    }

    await update({ tray_density });
    flashSaved();
  };

  const handleInterval = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!canInvokeTauri) {
      return;
    }

    const secs = parseInt(e.target.value, 10);
    if (!isNaN(secs)) {
      await update({ refresh_interval_secs: secs });
      flashSaved();
    }
  };

  const clearCache = async () => {
    if (!canInvokeTauri) {
      return;
    }

    try {
      requireTauriRuntime();
      await invoke('clear_cache');
      flashSaved();
    } catch (e) {
      console.error(e);
    }
  };

  const refreshUsage = async () => {
    if (!canInvokeTauri) {
      return;
    }

    try {
      requireTauriRuntime();
      await invoke('refresh_usage');
      flashSaved();
    } catch (e) {
      console.error(e);
    }
  };

  const flashSaved = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  };

  return (
    <div className="h-full flex flex-col">
      <header className="mx-4 mt-4 glass-toolbar px-5 py-3 rounded-2xl">
        <h1 className="text-lg font-semibold text-primary">Settings</h1>
      </header>

      <main className="flex-1 overflow-auto p-6 md:p-7">
        <div className="max-w-lg mx-auto w-full space-y-6">
          <Section title="Data Paths">
            <PathField
              label="Codex data root"
              value={config.codex_root}
              onBrowse={() => pickDirectory('codex_root')}
            />
            <PathField
              label="Cache directory"
              value={config.cache_dir}
              onBrowse={() => pickDirectory('cache_dir')}
            />
          </Section>

          <Section title="Appearance">
            <div className="grid grid-cols-3 gap-2">
              {(['light', 'dark', 'system'] as ThemeMode[]).map((t) => (
                <button
                  key={t}
                  onClick={() => handleTheme(t)}
                  disabled={!canInvokeTauri}
                  className={`px-3 py-2 rounded-full text-sm capitalize transition-all ${
                    config.theme === t ? 'glass-button-solid' : 'text-secondary glass-button'
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </Section>

          <Section title="Tray">
            <div className="grid grid-cols-3 gap-2">
              {(['minimal', 'classic', 'rich'] as TrayDensity[]).map((d) => (
                <button
                  key={d}
                  onClick={() => handleDensity(d)}
                  disabled={!canInvokeTauri}
                  className={`px-3 py-2 rounded-full text-sm capitalize transition-all ${
                    config.tray_density === d ? 'glass-button-solid' : 'text-secondary glass-button'
                  }`}
                >
                  {d}
                </button>
              ))}
            </div>
          </Section>

          <Section title="Refresh">
            <label className="block text-sm text-secondary mb-2">Auto-refresh interval (seconds)</label>
            <input
              type="number"
              min={10}
              max={3600}
              value={config.refresh_interval_secs}
              onChange={handleInterval}
              disabled={!canInvokeTauri}
              className="w-full px-3 py-2 glass-input text-primary text-sm"
            />
            <div className="flex gap-3 mt-4">
              <button
                onClick={refreshUsage}
                disabled={!canInvokeTauri}
                className="flex items-center gap-2 px-4 py-2 rounded-full glass-button-solid text-sm"
              >
                <RefreshCw size={14} /> Refresh now
              </button>
              <button
                onClick={clearCache}
                disabled={!canInvokeTauri}
                className="flex items-center gap-2 px-4 py-2 rounded-full glass-button text-status-error border-status-error/30 text-status-error text-sm"
              >
                <Trash2 size={14} /> Clear cache
              </button>
            </div>
          </Section>

          <Section title="About">
            <p className="text-sm text-secondary">Version 0.1.0</p>
            <p className="text-xs text-tertiary mt-2">Data folder: {settings.app_data_dir}</p>
            <p className="text-xs text-tertiary mt-2">
              Privacy: usage data is read locally and never uploaded.
            </p>
            {!canInvokeTauri && (
              <p className="text-xs text-status-warn mt-3">
                Running from browser: interactive actions are disabled. Open via Tauri app for full
                functionality.
              </p>
            )}
          </Section>

          {saved && <p className="text-center text-sm text-status-ok">Settings saved.</p>}
        </div>
      </main>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="glass-panel p-4 sm:p-5">
      <h2 className="text-sm font-semibold text-primary mb-3">{title}</h2>
      {children}
    </div>
  );
}

function PathField({
  label,
  value,
  onBrowse,
}: {
  label: string;
  value: string;
  onBrowse: () => void;
}) {
  return (
    <div className="mb-3 last:mb-0">
      <label className="block text-sm text-secondary mb-1">{label}</label>
      <div className="flex gap-2">
        <input
          readOnly
          value={value}
          className="flex-1 px-3 py-2 glass-input text-primary text-sm truncate"
        />
        <button
          onClick={onBrowse}
          className="px-3 py-2 rounded-full glass-button text-secondary"
        >
          <FolderOpen size={16} />
        </button>
      </div>
    </div>
  );
}

function applyTheme(theme: ThemeMode) {
  const root = document.documentElement;
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = theme === 'dark' || (theme === 'system' && prefersDark);
  root.classList.toggle('dark', isDark);
}
