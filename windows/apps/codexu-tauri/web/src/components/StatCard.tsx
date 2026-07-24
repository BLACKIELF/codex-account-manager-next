import type { ReactNode } from 'react';

interface StatCardProps {
  label: string;
  value: string;
  subValue?: string;
  icon?: ReactNode;
  accent?: 'primary' | 'secondary' | 'tertiary';
}

export function StatCard({ label, value, subValue, icon, accent = 'primary' }: StatCardProps) {
  const accentClass =
    accent === 'primary'
      ? 'bg-data-primary/10 text-data-primary'
      : accent === 'secondary'
      ? 'bg-data-secondary/10 text-data-secondary'
      : 'bg-data-tertiary/10 text-data-tertiary';

  return (
    <div className="bg-surface-elevated border border-theme rounded-xl p-4 flex items-start justify-between">
      <div>
        <p className="text-sm text-secondary font-medium">{label}</p>
        <p className="text-2xl font-semibold text-primary mt-1">{value}</p>
        {subValue && <p className="text-xs text-tertiary mt-1">{subValue}</p>}
      </div>
      {icon && (
        <div className={`p-2 rounded-lg ${accentClass}`}>{icon}</div>
      )}
    </div>
  );
}
