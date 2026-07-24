import { useEffect } from 'react';
import { Activity, Calendar, Coins, Layers } from 'lucide-react';
import { Header } from '../components/Header';
import { StatCard } from '../components/StatCard';
import { TokenBarChart } from '../components/TokenBarChart';
import { TrendChart } from '../components/TrendChart';
import { ThreadList } from '../components/ThreadList';
import { ProjectBoard } from '../components/ProjectBoard';
import { ToolUsageList } from '../components/ToolUsageList';
import { useUsage } from '../hooks/useUsage';
import { useSettings } from '../hooks/useSettings';

export function Dashboard() {
  const { usage, loading, error, refresh } = useUsage();
  const { settings, update } = useSettings();

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
          <div className="bg-status-error/10 text-status-error rounded-xl p-6 max-w-md">
            <h2 className="text-lg font-semibold mb-2">Failed to load usage</h2>
            <p className="text-sm opacity-90">{error}</p>
            <button
              onClick={refresh}
              className="mt-4 px-4 py-2 rounded-lg bg-status-error text-white text-sm hover:opacity-90"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  const detailed = usage?.detailed_usage;

  return (
    <div className="h-full flex flex-col bg-surface">
      <Header
        lastUpdated={usage?.last_updated_at ?? null}
        theme={settings?.config.theme ?? 'system'}
        onThemeChange={handleThemeChange}
        onRefresh={refresh}
        refreshing={loading}
      />

      <main className="flex-1 overflow-auto p-6">
        <div className="max-w-6xl mx-auto space-y-6">
          <div className="flex items-center gap-2 mb-2">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-status-warn/10 text-status-warn">
              <Activity size={12} /> Local only
            </span>
            <span className="text-xs text-tertiary">
              Codex · {usage?.thread_count ?? 0} threads
            </span>
          </div>

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
