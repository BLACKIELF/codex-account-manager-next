import { useMemo, useState } from 'react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { UsageTrend } from '../types/models';

interface TrendChartProps {
  trend: UsageTrend | null;
}

const RANGES = [
  { label: '30D', days: 30 },
  { label: '90D', days: 90 },
  { label: '180D', days: 180 },
];

export function TrendChart({ trend }: TrendChartProps) {
  const [range, setRange] = useState(30);

  const data = useMemo(() => {
    if (!trend) return [];
    const cutoff = Date.now() - range * 24 * 60 * 60 * 1000;
    return trend.day_buckets
      .filter((b) => b.date >= cutoff)
      .map((b) => ({
        date: new Date(b.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
        tokens: b.usage.tokens.total_tokens,
      }));
  }, [trend, range]);

  if (!trend || data.length === 0) {
    return (
      <div className="bg-surface-elevated border border-theme rounded-xl p-4">
        <h3 className="text-sm font-semibold text-primary mb-4">Usage Trend</h3>
        <p className="text-secondary text-sm">No trend data available.</p>
      </div>
    );
  }

  return (
    <div className="bg-surface-elevated border border-theme rounded-xl p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-primary">Usage Trend</h3>
        <div className="flex gap-1">
          {RANGES.map((r) => (
            <button
              key={r.days}
              onClick={() => setRange(r.days)}
              className={`px-2 py-1 text-xs rounded-md transition-colors ${
                range === r.days
                  ? 'bg-accent text-white'
                  : 'bg-surface-inset text-secondary hover:text-primary'
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>
      <div className="h-56">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
            <defs>
              <linearGradient id="colorTokens" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="var(--data-primary)" stopOpacity={0.35} />
                <stop offset="95%" stopColor="var(--data-primary)" stopOpacity={0.02} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fill: 'var(--text-secondary)', fontSize: 11 }}
              axisLine={{ stroke: 'var(--border)' }}
              tickLine={false}
              minTickGap={24}
            />
            <YAxis
              tick={{ fill: 'var(--text-secondary)', fontSize: 12 }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v: number) => formatCompact(v)}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: 'var(--surface-elevated)',
                border: '1px solid var(--border)',
                borderRadius: '8px',
                color: 'var(--text-primary)',
              }}
              formatter={(value: number) => [formatNumber(value), 'Tokens']}
            />
            <Area
              type="monotone"
              dataKey="tokens"
              stroke="var(--data-primary)"
              strokeWidth={2}
              fill="url(#colorTokens)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

function formatCompact(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return String(n);
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}
