import { createContext, useCallback, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useSettings } from '../hooks/useSettings';
import { isTauriRuntimeAvailable } from '../utils/tauri';
import {
  getMessages,
  interpolate,
  readMessage,
  resolveInterfaceLanguage,
  type InterfaceLanguage,
  type MessageKey,
  type Messages,
  type ResolvedInterfaceLanguage,
} from './messages';

interface I18nContextValue {
  preference: InterfaceLanguage;
  language: ResolvedInterfaceLanguage;
  messages: Messages;
  setPreference: (preference: InterfaceLanguage) => Promise<void>;
  t: (key: MessageKey, values?: Record<string, string | number>) => string;
}

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const { settings, update } = useSettings();
  const preference = settings?.config.language ?? 'auto';
  const language = resolveInterfaceLanguage(preference);
  const localizedMessages = useMemo(() => getMessages(language), [language]);

  useEffect(() => {
    document.documentElement.lang = language;
    if (!isTauriRuntimeAvailable()) return;

    invoke('sync_runtime_language', { language }).catch((error) => {
      console.error('[I18n] Failed to sync runtime language:', error);
    });
  }, [language]);

  const setPreference = useCallback(
    async (nextPreference: InterfaceLanguage) => {
      await update({ language: nextPreference });
    },
    [update],
  );

  const value = useMemo<I18nContextValue>(
    () => ({
      preference,
      language,
      messages: localizedMessages,
      setPreference,
      t: (key, values) => interpolate(readMessage(localizedMessages, key), values),
    }),
    [language, localizedMessages, preference, setPreference],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const context = useContext(I18nContext);
  if (!context) throw new Error('useI18n must be used within I18nProvider');
  return context;
}
