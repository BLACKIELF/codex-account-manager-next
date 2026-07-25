import { useCallback, useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import type { LocalUsage } from '../types/models';
import {
  isTauriRuntimeAvailable,
  requireTauriRuntime,
} from '../utils/tauri';

export function useUsage() {
  const [usage, setUsage] = useState<LocalUsage | null | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (force = false) => {
    setLoading(true);
    setError(null);
    try {
      requireTauriRuntime();
      const result = await invoke<LocalUsage | null>(
        force ? 'refresh_usage' : 'get_local_usage'
      );
      setUsage(result);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, []);

useEffect(() => {
  load();

  if (!isTauriRuntimeAvailable()) {
    return;
  }

  let unlisten: (() => void) | null = null;
  let cancelled = false;

  const subscribe = async () => {
    try {
      const unlistenFn = await listen('usage:updated', () => {
        load();
      });
      if (cancelled) {
        unlistenFn();
      } else {
        unlisten = unlistenFn;
      }
    } catch (e) {
      setError(String(e));
    }
  };
  subscribe();

  return () => {
    cancelled = true;
    unlisten?.();
  };
}, [load]);

  return { usage, loading, error, refresh: () => load(true) };
}
