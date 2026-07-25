import { isTauri } from '@tauri-apps/api/core';

const hasTauriInternals = (): boolean => {
  const anyGlobal = globalThis as { [key: string]: unknown };
  const tauriInternals = anyGlobal.__TAURI_INTERNALS__;
  return (
    isTauri() &&
    !!tauriInternals &&
    typeof (tauriInternals as { invoke?: unknown }).invoke === 'function'
  );
};

export const isTauriRuntimeAvailable = (): boolean => hasTauriInternals();

export const requireTauriRuntime = (): void => {
  if (!hasTauriInternals()) {
    throw new Error(
      'Tauri runtime is unavailable. Run the app via `cargo tauri dev` (or packaged `.exe`) instead of opening `localhost:1420` in a browser.'
    );
  }
};
