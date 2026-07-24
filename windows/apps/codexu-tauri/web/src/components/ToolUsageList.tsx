import { Wrench } from 'lucide-react';
import type { ToolUsage } from '../types/models';

interface ToolUsageListProps {
  tools: ToolUsage[];
}

export function ToolUsageList({ tools }: ToolUsageListProps) {
  if (tools.length === 0) {
    return (
      <div className="bg-surface-elevated border border-theme rounded-xl p-4">
        <h3 className="text-sm font-semibold text-primary mb-4">Tools</h3>
        <p className="text-secondary text-sm">No tool usage found.</p>
      </div>
    );
  }

  const maxCalls = Math.max(...tools.map((t) => t.call_count), 1);

  return (
    <div className="bg-surface-elevated border border-theme rounded-xl p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-primary">Tools</h3>
        <span className="text-xs text-tertiary">{tools.length} total</span>
      </div>
      <div className="space-y-3">
        {tools.map((t) => (
          <div key={t.id} className="space-y-1">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2">
                <Wrench size={14} className="text-secondary" />
                <span className="font-medium text-primary">{t.name}</span>
                <span className="text-xs px-1.5 py-0.5 rounded bg-surface-inset text-tertiary capitalize">
                  {t.category}
                </span>
              </div>
              <span className="text-secondary">{formatNumber(t.call_count)}</span>
            </div>
            <div className="h-2 w-full bg-surface-inset rounded-full overflow-hidden">
              <div
                className="h-full bg-data-tertiary rounded-full"
                style={{ width: `${(t.call_count / maxCalls) * 100}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}
