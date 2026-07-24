import { useEffect, useState } from 'react';
import { open } from '@tauri-apps/plugin-dialog';
import { FolderOpen, RefreshCw, Trash2 } from 'lucide-react';
import { invoke } from '@tauri-apps/api/core';
import { useSettings } from '../hooks/useSettings';
import type { ThemeMode, TrayDensity } from '../types/settings';

export function Settings() {
  const { settings, update } = useSettings();
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    applyTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

  if (!settings) {
    return (
      <div className="h-full flex items-center justify-center bg-surface text-secondary">
        Loading settings…
      </div>
    );
  }

  const config = settings.config;

  const pickDirectory = async (key: 'codex_root' | 'cache_dir') => {
    const selected = await open({ directory: true });
    if (selected) {
      await update({ [key]: selected });
      flashSaved();
    }
  };

  const handleTheme = async (theme: ThemeMode) => {
    await update({ theme });
    applyTheme(theme);
    flashSaved();
  };

  const handleDensity = async (tray_density: TrayDensity) => {
    await update({ tray_density });
    flashSaved();
  };

  const handleInterval = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const secs = parseInt(e.target.value, 10);
    if (!isNaN(secs)) {
      await update({ refresh_interval_secs: secs });
      flashSaved();
    }
  };

  const clearCache = async () => {
    await invoke('clear_cache');
    flashSaved();
  };

  const flashSaved = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  };

  return (
    <div className="h-full flex flex-col bg-surface">
      <header className="px-6 py-4 border-b border-theme bg-surface-elevated">
        <h1 className="text-lg font-semibold text-primary">Settings</h1>
      </header>

      <main className="flex-1 overflow-auto p-6">
        <div className="max-w-lg mx-auto space-y-6">
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
                  className={`px-3 py-2 rounded-lg border text-sm capitalize transition-colors ${
                    config.theme === t
                      ? 'border-accent bg-accent/10 text-accent'
                      : 'border-theme text-secondary hover:text-primary'
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
                  className={`px-3 py-2 rounded-lg border text-sm capitalize transition-colors ${
                    config.tray_density === d
                      ? 'border-accent bg-accent/10 text-accent'
                      : 'border-theme text-secondary hover:text-primary'
                  }`}
                >
                  {d}
                </button>
              ))}
            </div>
          </Section>

          <Section title="Refresh">
            <label className="block text-sm text-secondary mb-2">
              Auto-refresh interval (seconds)
            </label>
            <input
              type="number"
              min={10}
              max={3600}
              value={config.refresh_interval_secs}
              onChange={handleInterval}
              className="w-full px-3 py-2 rounded-lg bg-surface-inset border border-theme text-primary text-sm focus:outline-none focus:border-accent"
            />
            <div className="flex gap-3 mt-4">
              <button
                onClick={() => invoke('refresh_usage')}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-accent text-white text-sm hover:opacity-90"
              >
                <RefreshCw size={14} /> Refresh now
              </button>
              <button
                onClick={clearCache}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-status-error/10 text-status-error text-sm hover:bg-status-error/20"
              >
                <Trash2 size={14} /> Clear cache
              </button>
            </div>
          </Section>

          <Section title="About">
            <p className="text-sm text-secondary">Version 0.1.0</p>
            <p className="text-xs text-tertiary mt-2">
              Data folder: {settings.app_data_dir}
            </p>
            <p className="text-xs text-tertiary mt-2">
              Privacy: usage data is read locally and never uploaded.
            </p>
          </Section>

          {saved && (
            <p className="text-center text-sm text-status-ok">Settings saved.</p>
          )}
        </div>
      </main>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-surface-elevated border border-theme rounded-xl p-4">
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
          className="flex-1 px-3 py-2 rounded-lg bg-surface-inset border border-theme text-primary text-sm truncate"
        />
        <button
          onClick={onBrowse}
          className="px-3 py-2 rounded-lg bg-surface-inset border border-theme text-secondary hover:text-primary"
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
