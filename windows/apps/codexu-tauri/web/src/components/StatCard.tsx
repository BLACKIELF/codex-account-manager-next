import type { ReactNode } from 'react';

interface StatCardProps {
  label: string;
  value: string;
  subValue?: string;
  icon?: ReactNode;
  accent?: 'primary' | 'secondary' | 'tertiary';
  compact?: boolean;
}

export function StatCard({ label, value, subValue, icon, accent = 'primary', compact = false }: StatCardProps) {
  const accentClass =
    accent === 'primary'
      ? 'bg-data-primary/20 text-data-primary'
      : accent === 'secondary'
      ? 'bg-data-secondary/20 text-data-secondary'
      : 'bg-data-tertiary/20 text-data-tertiary';

  const contentClass = compact ? 'text-sm text-secondary font-medium' : 'text-sm text-secondary font-medium';
  const valueClass = compact ? 'text-lg font-semibold text-primary mt-1' : 'text-2xl font-semibold text-primary mt-1';
  const subValueClass = compact ? 'text-[11px] text-tertiary mt-1' : 'text-xs text-tertiary mt-1';
  const iconClass = compact ? 'p-1.5 rounded-lg' : 'p-2 rounded-lg';
  const cardClass = compact ? 'glass-panel p-3 sm:p-3 flex items-start justify-between gap-2' : 'glass-panel p-4 sm:p-5';

  return (
    <div className={cardClass}>
      <div className={compact ? 'min-w-0 flex-1' : ''}>
        <p className={contentClass}>{label}</p>
        <p className={valueClass}>{value}</p>
        {subValue && <p className={subValueClass}>{subValue}</p>}
      </div>
      {icon && (
        <div className={`${iconClass} ${accentClass} border border-current/20`} aria-hidden="true">
          {icon}
        </div>
      )}
    </div>
  );
}
