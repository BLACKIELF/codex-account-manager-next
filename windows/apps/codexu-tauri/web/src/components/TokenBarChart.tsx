import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { DailyTokenBucket } from '../types/models';
import { useI18n } from '../i18n/I18nProvider';

interface TokenBarChartProps {
  data: DailyTokenBucket[];
}

export function TokenBarChart({ data }: TokenBarChartProps) {
  const { t } = useI18n();
  const chartData = data.map((d) => ({
    label: d.label,
    tokens: d.tokens,
  }));

  return (
    <div className="glass-panel p-4 sm:p-5">
      <h3 className="text-sm font-semibold text-primary mb-4">{t('usage.sevenDayUsage')}</h3>
      <div className="h-48">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
            <XAxis
              dataKey="label"
              tick={{ fill: 'var(--text-secondary)', fontSize: 12 }}
              axisLine={{ stroke: 'var(--border)' }}
              tickLine={false}
            />
            <YAxis
              tick={{ fill: 'var(--text-secondary)', fontSize: 12 }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v: number) => formatCompact(v)}
            />
            <Tooltip
              cursor={{ fill: 'var(--surface-inset)' }}
              contentStyle={{
                backgroundColor: 'var(--surface-elevated)',
                border: '1px solid var(--border)',
                borderRadius: '8px',
                color: 'var(--text-primary)',
              }}
              formatter={(value: number) => [formatNumber(value), t('usage.tokenLabel')]}
            />
            <Bar dataKey="tokens" fill="var(--data-primary)" radius={[4, 4, 0, 0]} />
          </BarChart>
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
