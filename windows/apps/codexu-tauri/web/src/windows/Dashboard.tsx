import { useEffect } from 'react';
import { Activity, CircleDashed } from 'lucide-react';
import { Header } from '../components/Header';
import { DashboardHome } from '../components/DashboardHome';
import { useSettings } from '../hooks/useSettings';
import { useUsage } from '../hooks/useUsage';
import { applyAppTheme } from '../utils/appTheme';

export function Dashboard() {
  const { dashboard, loading, error, refresh } = useUsage();
  const { settings, update } = useSettings();

  useEffect(() => {
    applyAppTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

  const localUsage = dashboard?.codex?.snapshot?.local ?? null;
  const lastUpdated =
    dashboard?.codex?.snapshot?.refreshed_at ?? dashboard?.refreshed_at ?? localUsage?.last_updated_at ?? null;
  const quotaStatus = dashboard?.codex?.status ?? 'local_only';
  const quotaStatusLabel =
    quotaStatus === 'available'
      ? 'Official quota active'
      : quotaStatus === 'stale'
        ? 'Official quota last verified'
        : 'Checking official quota';
  const quotaStatusClass =
    quotaStatus === 'available'
      ? 'bg-status-ok/12 text-status-ok border-status-ok/30'
      : 'bg-status-warn/12 text-status-warn border-status-warn/30';

  const handleThemeChange = async (theme: 'system' | 'light' | 'dark') => {
    await update({ theme });
    applyAppTheme(theme);
  };

  if (error) {
    return (
      <div className="h-full flex flex-col">
        <Header
          lastUpdated={null}
          theme={settings?.config.theme ?? 'system'}
          onThemeChange={handleThemeChange}
          onRefresh={refresh}
          refreshing={loading}
        />
        <div className="flex-1 flex items-center justify-center p-6">
          <div className="glass-panel p-6 max-w-md border-status-error/30 bg-status-error/8">
            <h2 className="text-lg font-semibold text-status-error mb-2">Failed to load usage</h2>
            <p className="text-sm opacity-90 text-status-error/90">{error}</p>
            <button
              onClick={refresh}
              className="mt-4 px-4 py-2 rounded-full glass-button-solid text-sm"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <Header
        lastUpdated={lastUpdated}
        theme={settings?.config.theme ?? 'system'}
        onThemeChange={handleThemeChange}
        onRefresh={refresh}
        refreshing={loading}
      />

      <main className="flex-1 overflow-auto p-6 md:p-7">
        {!dashboard && (
          <div className="glass-panel p-6 mb-6" role="status" aria-live="polite">
            {loading ? (
              <>
                <h2 className="text-sm font-semibold text-primary">Loading usage data</h2>
                <p className="text-sm text-secondary mt-1">Collecting local snapshots...</p>
              </>
            ) : (
              <>
                <h2 className="text-sm font-semibold text-primary">No usage snapshot yet</h2>
                <p className="text-sm text-secondary mt-1">
                  No local usage data is available yet. Click Refresh to sample your latest sessions.
                </p>
                <button
                  onClick={refresh}
                  className="mt-4 px-4 py-2 rounded-full glass-button-solid text-sm"
                >
                  Refresh now
                </button>
              </>
            )}
          </div>
        )}

        <div className="max-w-6xl mx-auto w-full space-y-6">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className={`inline-flex items-center gap-1.5 chip-like ${quotaStatusClass}`}>
                <Activity size={12} /> {quotaStatusLabel}
              </span>
              <span className="text-xs text-tertiary">Codex {(localUsage?.thread_count ?? 0)} threads</span>
              {!localUsage ? (
                <span className="text-xs text-tertiary">
                  {dashboard ? 'No local usage details yet' : 'Waiting for snapshot'}
                </span>
              ) : null}
            </div>
            <span className="inline-flex items-center gap-1.5 chip-like text-xs text-secondary">
              <CircleDashed size={12} />
              Last update: {lastUpdated ? new Date(lastUpdated).toLocaleTimeString() : 'waiting'}
            </span>
          </div>
          {dashboard?.messages?.length ? (
            <p className="text-xs text-tertiary mt-2">Status: {dashboard.messages.join(' 路 ')}</p>
          ) : null}

          <DashboardHome
            snapshot={dashboard?.codex?.snapshot}
            quotaSourceLabel={dashboard?.codex?.quota_source_label}
            leadershipSignal={dashboard?.leadership ?? null}
            onQuotaRefresh={refresh}
          />
        </div>
      </main>
    </div>
  );
}
