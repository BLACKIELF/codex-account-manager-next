import { Activity, Calendar, Coins, TrendingUp } from 'lucide-react';
import type { LocalUsage } from '../types/models';
import { StatCard } from './StatCard';
import { TokenBarChart } from './TokenBarChart';
import { TrendChart } from './TrendChart';

interface UsagePanelProps {
  usage: LocalUsage | null | undefined;
}

export function UsagePanel({ usage }: UsagePanelProps) {
  const detailed = usage?.detailed_usage ?? null;
  const hasUsage = usage !== null && usage !== undefined;

  return (
    <section className="space-y-6">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Today"
          value={formatNumber(hasUsage ? usage?.today_tokens : null)}
          subValue={detailed ? `$${formatUSD(detailed.today.estimated_cost_usd)} est.` : 'Record insufficient'}
          icon={<Activity size={18} />}
          accent="primary"
        />
        <StatCard
          label="7-Day"
          value={formatNumber(hasUsage ? usage?.seven_day_tokens : null)}
          subValue={detailed ? `$${formatUSD(detailed.seven_day.estimated_cost_usd)} est.` : 'Record insufficient'}
          icon={<Calendar size={18} />}
          accent="secondary"
        />
        <StatCard
          label="Lifetime"
          value={formatNumber(hasUsage ? usage?.lifetime_tokens : null)}
          subValue={detailed ? `$${formatUSD(detailed.lifetime.estimated_cost_usd)} est.` : 'Record insufficient'}
          icon={<TrendingUp size={18} />}
          accent="tertiary"
        />
        <StatCard
          label="Est. Cost (lifetime)"
          value={detailed ? `$${formatUSD(detailed.lifetime.estimated_cost_usd)}` : 'Record insufficient'}
          subValue="Local snapshot estimate"
          icon={<Coins size={18} />}
          accent="primary"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <TokenBarChart data={usage?.daily_buckets ?? []} />
        <TrendChart trend={usage?.usage_trend ?? null} />
      </div>
    </section>
  );
}

function formatNumber(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return value.toLocaleString();
}

function formatUSD(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return value.toFixed(2);
}
