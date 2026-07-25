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
      ? 'bg-data-primary/20 text-data-primary'
      : accent === 'secondary'
      ? 'bg-data-secondary/20 text-data-secondary'
      : 'bg-data-tertiary/20 text-data-tertiary';

  return (
    <div className="glass-panel p-4 sm:p-5">
      <div>
        <p className="text-sm text-secondary font-medium">{label}</p>
        <p className="text-2xl font-semibold text-primary mt-1">{value}</p>
        {subValue && <p className="text-xs text-tertiary mt-1">{subValue}</p>}
      </div>
      {icon && (
        <div className={`p-2 rounded-lg ${accentClass} border border-current/20`}>{icon}</div>
      )}
    </div>
  );
}
