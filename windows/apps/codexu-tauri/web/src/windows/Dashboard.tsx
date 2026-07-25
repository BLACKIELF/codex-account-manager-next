import { useEffect, useState } from 'react';
import {
  Activity,
  Calendar,
  ChevronRight,
  CircleDashed,
  Coins,
  Layers,
} from 'lucide-react';
import { Header } from '../components/Header';
import { LeadershipPanel } from '../components/LeadershipPanel';
import { ProjectBoard } from '../components/ProjectBoard';
import { StatCard } from '../components/StatCard';
import { ThreadList } from '../components/ThreadList';
import { TokenBarChart } from '../components/TokenBarChart';
import { ToolUsageList } from '../components/ToolUsageList';
import { TrendChart } from '../components/TrendChart';
import { useSettings } from '../hooks/useSettings';
import { useUsage } from '../hooks/useUsage';

type DashboardTab = 'overview' | 'leadership' | 'threads' | 'projects';

const TABS: Array<{ id: DashboardTab; title: string }> = [
  { id: 'overview', title: 'Overview' },
  { id: 'leadership', title: 'AI Leadership' },
  { id: 'threads', title: 'Threads' },
  { id: 'projects', title: 'Projects' },
];

export function Dashboard() {
  const { usage, loading, error, refresh } = useUsage();
  const { settings, update } = useSettings();
  const [activeTab, setActiveTab] = useState<DashboardTab>('overview');

  useEffect(() => {
    applyTheme(settings?.config.theme ?? 'system');
  }, [settings?.config.theme]);

  const handleThemeChange = async (theme: 'system' | 'light' | 'dark') => {
    await update({ theme });
    applyTheme(theme);
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

  const detailed = usage?.detailed_usage;
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
            className="rounded-2xl p-1 glass-toolbar flex gap-1.5 flex-wrap"
            role="tablist"
            aria-label="dashboard tabs"
          >
            {TABS.map((tab) => (
              <button
                key={tab.id}
                role="tab"
                aria-selected={activeTab === tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`px-3 py-2 rounded-xl text-sm transition-all ${
                  activeTab === tab.id ? 'glass-button-solid' : 'text-secondary glass-button'
                }`}
              >
                {tab.title}
              </button>
            ))}
          </div>

          {activeTab === 'overview' && (
            <section className="space-y-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard
                  label="Today"
                  value={formatNumber(usage?.today_tokens ?? 0)}
                  subValue={detailed ? `$${detailed.today.estimated_cost_usd.toFixed(2)} est.` : undefined}
                  icon={<Activity size={18} />}
                  accent="primary"
                />
                <StatCard
                  label="7-Day"
                  value={formatNumber(usage?.seven_day_tokens ?? 0)}
                  subValue={detailed ? `$${detailed.seven_day.estimated_cost_usd.toFixed(2)} est.` : undefined}
                  icon={<Calendar size={18} />}
                  accent="secondary"
                />
                <StatCard
                  label="Lifetime"
                  value={formatNumber(usage?.lifetime_tokens ?? 0)}
                  subValue={detailed ? `$${detailed.lifetime.estimated_cost_usd.toFixed(2)} est.` : undefined}
                  icon={<Layers size={18} />}
                  accent="tertiary"
                />
                <StatCard
                  label="Est. Cost"
                  value={`$${(detailed?.lifetime.estimated_cost_usd ?? 0).toFixed(2)}`}
                  subValue="Lifetime"
                  icon={<Coins size={18} />}
                  accent="primary"
                />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <TokenBarChart data={usage?.daily_buckets ?? []} />
                <TrendChart trend={usage?.usage_trend ?? null} />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <ThreadList threads={usage?.recent_threads ?? []} />
                <ProjectBoard projects={usage?.project_board?.recent_projects ?? []} />
              </div>

              <ToolUsageList tools={usage?.tool_usages ?? []} />
            </section>
          )}

          {activeTab === 'threads' && (
            <section className="space-y-4">
              <header className="glass-panel p-4 sm:p-5">
                <div className="flex items-center justify-between text-sm">
                  <h2 className="font-semibold text-primary">Threads</h2>
                  <button
                    className="inline-flex items-center gap-1 text-secondary hover:text-primary"
                    onClick={() => setActiveTab('overview')}
                  >
                    <ChevronRight size={14} className="rotate-180" />
                    Overview
                  </button>
                </div>
              </header>
              <ThreadList threads={usage?.recent_threads ?? []} />
            </section>
          )}

          {activeTab === 'projects' && (
            <section className="space-y-4">
              <header className="glass-panel p-4 sm:p-5">
                <div className="flex items-center justify-between text-sm">
                  <h2 className="font-semibold text-primary">Projects</h2>
                  <button
                    className="inline-flex items-center gap-1 text-secondary hover:text-primary"
                    onClick={() => setActiveTab('overview')}
                  >
                    <ChevronRight size={14} className="rotate-180" />
                    Overview
                  </button>
                </div>
              </header>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <ProjectBoard projects={usage?.project_board?.recent_projects ?? []} />
                <ToolUsageList tools={usage?.tool_usages ?? []} />
              </div>
            </section>
          )}

          {activeTab === 'leadership' && (
            <section>
              {isLeadershipAvailable ? (
                <LeadershipPanel snapshot={usage?.leadership ?? null} />
              ) : (
                <div className="glass-panel p-6">
                  <p className="text-sm text-secondary">
                    No leadership snapshot yet. Move usage to continue collecting automation traces and
                    refresh.
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

function applyTheme(theme: 'system' | 'light' | 'dark') {
  const root = document.documentElement;
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = theme === 'dark' || (theme === 'system' && prefersDark);
  root.classList.toggle('dark', isDark);
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}
