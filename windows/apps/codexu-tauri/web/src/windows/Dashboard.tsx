import { useEffect, useState, type KeyboardEvent } from 'react';
import { Activity, ChevronRight, CircleDashed } from 'lucide-react';
import { Header } from '../components/Header';
import { DashboardHome } from '../components/DashboardHome';
import { ThreadList } from '../components/ThreadList';
import { LeadershipPanel } from '../components/LeadershipPanel';
import { useSettings } from '../hooks/useSettings';
import { useUsage } from '../hooks/useUsage';
import { applyAppTheme } from '../utils/appTheme';

type DashboardTab = 'home' | 'leadership' | 'threads';

const TABS: Array<{ id: DashboardTab; title: string }> = [
  { id: 'home', title: 'Dashboard' },
  { id: 'leadership', title: 'AI Leadership' },
  { id: 'threads', title: 'Threads' },
];

export function Dashboard() {
  const { dashboard, loading, error, refresh } = useUsage();
  const { settings, update } = useSettings();
  const [activeTab, setActiveTab] = useState<DashboardTab>('home');

  useEffect(() => {
    applyAppTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

  const localUsage = dashboard?.codex?.snapshot?.local ?? null;
  const hasUsage = localUsage !== null;
  const isLeadershipAvailable = dashboard?.leadership?.report !== null;
  const lastUpdated =
    localUsage?.last_updated_at ?? dashboard?.refreshed_at ?? dashboard?.codex?.snapshot?.refreshed_at ?? null;

  const handleThemeChange = async (theme: 'system' | 'light' | 'dark') => {
    await update({ theme });
    applyAppTheme(theme);
  };

  const handleTabKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
      return;
    }

    const currentIndex = TABS.findIndex((item) => item.id === activeTab);
    if (currentIndex < 0) return;

    event.preventDefault();
    const nextIndex =
      event.key === 'ArrowRight'
        ? (currentIndex + 1) % TABS.length
        : (currentIndex - 1 + TABS.length) % TABS.length;
    setActiveTab(TABS[nextIndex].id);
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
              <span className="inline-flex items-center gap-1.5 chip-like bg-status-warn/12 text-status-warn border-status-warn/30">
                <Activity size={12} /> Local only
              </span>
              <span className="text-xs text-tertiary">
                Codex {(localUsage?.thread_count ?? 0)} threads
              </span>
              {!hasUsage ? (
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
            <p className="text-xs text-tertiary mt-2">
              Status: {dashboard.messages.join(' · ')}
            </p>
          ) : null}

          <div
            onKeyDown={handleTabKeyDown}
            className="rounded-2xl p-1 glass-toolbar flex gap-1.5 flex-wrap"
            role="tablist"
            aria-label="dashboard tabs"
            tabIndex={0}
          >
            {TABS.map((tab) => (
              <button
                key={tab.id}
                id={`dashboard-tab-${tab.id}`}
                role="tab"
                aria-selected={activeTab === tab.id}
                aria-controls={`dashboard-panel-${tab.id}`}
                onClick={() => setActiveTab(tab.id)}
                className={`px-3 py-2 rounded-xl text-sm transition-all ${
                  activeTab === tab.id ? 'glass-button-solid' : 'text-secondary glass-button'
                }`}
              >
                {tab.title}
              </button>
            ))}
          </div>

          {activeTab === 'home' && (
            <section
              role="tabpanel"
              id="dashboard-panel-home"
              aria-labelledby="dashboard-tab-home"
              className="space-y-6"
            >
              <DashboardHome
                usage={localUsage}
                leadershipSignal={dashboard?.leadership ?? null}
                onOpenLeadership={() => setActiveTab('leadership')}
              />
            </section>
          )}

          {activeTab === 'threads' && (
            <section
              role="tabpanel"
              id="dashboard-panel-threads"
              aria-labelledby="dashboard-tab-threads"
              className="space-y-4"
            >
              <header className="glass-panel p-4 sm:p-5">
                <div className="flex items-center justify-between text-sm">
                  <h2 className="font-semibold text-primary">Threads</h2>
                  <button
                    aria-label="Back to Leadership"
                    className="inline-flex items-center gap-1 text-secondary hover:text-primary"
                    onClick={() => setActiveTab('leadership')}
                  >
                    <ChevronRight size={14} className="rotate-180" />
                    Leadership
                  </button>
                </div>
              </header>
              <ThreadList threads={localUsage?.recent_threads ?? []} />
            </section>
          )}

          {activeTab === 'leadership' && (
            <section
              role="tabpanel"
              id="dashboard-panel-leadership"
              aria-labelledby="dashboard-tab-leadership"
            >
              {isLeadershipAvailable ? (
                <LeadershipPanel signal={dashboard?.leadership ?? null} />
              ) : (
                <section className="glass-panel p-6">
                  <p className="text-sm text-secondary">
                    No leadership snapshot yet. Keep using local sessions and refresh to load leadership
                    details.
                  </p>
                </section>
              )}
            </section>
          )}

          {!hasUsage && dashboard && activeTab !== 'leadership' ? (
            <section className="glass-panel p-4 text-sm text-secondary">
              <p>No local usage details yet. Local usage summary will appear after first snapshot.</p>
            </section>
          ) : null}
        </div>
      </main>
    </div>
  );
}
