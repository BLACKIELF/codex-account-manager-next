import { useEffect, useState, type KeyboardEvent } from 'react';
import { Activity, ChevronRight, CircleDashed } from 'lucide-react';
import { Header } from '../components/Header';
import { DashboardHome } from '../components/DashboardHome';
import { ProjectBoard } from '../components/ProjectBoard';
import { LeadershipPanel } from '../components/LeadershipPanel';
import { ThreadList } from '../components/ThreadList';
import { UsagePanel } from '../components/UsagePanel';
import { ProjectsPanel } from '../components/ProjectsPanel';
import { ToolUsageList } from '../components/ToolUsageList';
import { useSettings } from '../hooks/useSettings';
import { useUsage } from '../hooks/useUsage';
import { applyAppTheme } from '../utils/appTheme';

type DashboardTab = 'home' | 'overview' | 'leadership' | 'threads' | 'projects';

const TABS: Array<{ id: DashboardTab; title: string }> = [
  { id: 'home', title: 'Dashboard' },
  { id: 'leadership', title: 'AI Leadership' },
  { id: 'threads', title: 'Threads' },
];

export function Dashboard() {
  const { usage, loading, error, refresh } = useUsage();
  const { settings, update } = useSettings();
  const [activeTab, setActiveTab] = useState<DashboardTab>('home');

  useEffect(() => {
    applyAppTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

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

  const hasUsage = usage !== null && usage !== undefined;

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

  const isLeadershipAvailable = usage?.leadership && usage.leadership.reports.length > 0;

  return (
    <div className="h-full flex flex-col">
      <Header
        lastUpdated={usage?.last_updated_at ?? null}
        theme={settings?.config.theme ?? 'system'}
        onThemeChange={handleThemeChange}
        onRefresh={refresh}
        refreshing={loading}
      />

      <main className="flex-1 overflow-auto p-6 md:p-7">
        {!hasUsage ? (
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
        ) : null}

        <div className="max-w-6xl mx-auto w-full space-y-6">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center gap-1.5 chip-like bg-status-warn/12 text-status-warn border-status-warn/30">
                <Activity size={12} /> Local only
              </span>
              <span className="text-xs text-tertiary">Codex {usage?.thread_count ?? 0} threads</span>
            </div>
            <span className="inline-flex items-center gap-1.5 chip-like text-xs text-secondary">
              <CircleDashed size={12} />
              Last update:
              {usage?.last_updated_at ? new Date(usage.last_updated_at).toLocaleTimeString() : 'waiting'}
            </span>
          </div>

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
              <DashboardHome usage={usage} onOpenLeadership={() => setActiveTab('leadership')} />
            </section>
          )}

          {activeTab === 'overview' && (
            <section
              role="tabpanel"
              id="dashboard-panel-overview"
              aria-labelledby="dashboard-tab-overview"
              className="space-y-6"
            >
              <UsagePanel usage={usage} />

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <ThreadList threads={usage?.recent_threads ?? []} />
                <ProjectBoard projects={usage?.project_board?.recent_projects ?? []} />
              </div>
              <ToolUsageList tools={usage?.tool_usages ?? []} />
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
              <ThreadList threads={usage?.recent_threads ?? []} />
            </section>
          )}

          {activeTab === 'projects' && (
            <section
              role="tabpanel"
              id="dashboard-panel-projects"
              aria-labelledby="dashboard-tab-projects"
              className="space-y-4"
            >
              <header className="glass-panel p-4 sm:p-5">
                <div className="flex items-center justify-between text-sm">
                  <h2 className="font-semibold text-primary">Projects</h2>
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
              <ProjectsPanel
                projects={usage?.project_board?.recent_projects ?? []}
                tools={usage?.tool_usages ?? []}
              />
            </section>
          )}

          {activeTab === 'leadership' && (
            <section
              role="tabpanel"
              id="dashboard-panel-leadership"
              aria-labelledby="dashboard-tab-leadership"
            >
              {isLeadershipAvailable ? (
                <LeadershipPanel snapshot={usage?.leadership ?? null} />
              ) : (
                <div className="glass-panel p-6">
                  <p className="text-sm text-secondary">
                    No leadership snapshot yet. Move usage to continue collecting automation traces and refresh.
                  </p>
                </div>
              )}
            </section>
          )}
        </div>
      </main>
    </div>
  );
}
