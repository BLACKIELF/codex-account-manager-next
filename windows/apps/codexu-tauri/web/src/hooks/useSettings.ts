import { useCallback, useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import type { AppConfig, SettingsDto } from '../types/settings';

export function useSettings() {
  const [settings, setSettings] = useState<SettingsDto | null>(null);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const dto = await invoke<SettingsDto>('get_settings');
      setSettings(dto);
    } finally {
      setLoading(false);
    }
  }, []);

  const update = useCallback(async (patch: Partial<AppConfig>) => {
    const updated = await invoke<AppConfig>('set_settings', patch);
    setSettings((prev) => (prev ? { ...prev, config: updated } : null));
  }, []);

  useEffect(() => {
    load();
    const unlistenPromise = listen('settings:changed', () => {
      load();
    });
    return () => {
      unlistenPromise.then((unlisten) => unlisten());
    };
  }, [load]);

  return { settings, loading, update, reload: load };
}
