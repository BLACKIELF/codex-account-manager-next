import { Folder } from 'lucide-react';
import type { ProjectUsage } from '../types/models';

interface ProjectBoardProps {
  projects: ProjectUsage[];
}

export function ProjectBoard({ projects }: ProjectBoardProps) {
  if (projects.length === 0) {
    return (
      <div className="glass-panel p-4 sm:p-5">
        <h3 className="text-sm font-semibold text-primary mb-4">Projects</h3>
        <p className="text-secondary text-sm">No projects found.</p>
      </div>
    );
  }

  const maxTokens = Math.max(...projects.map((p) => p.tokens), 1);

  return (
    <div className="glass-panel p-4 sm:p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-primary">Projects</h3>
        <span className="text-xs text-tertiary">{projects.length} total</span>
      </div>
      <div className="space-y-3 max-h-80 overflow-auto">
        {projects.slice(0, 20).map((p) => (
          <div key={p.id} className="space-y-1">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2 min-w-0">
                <Folder size={14} className="text-secondary shrink-0" />
                <span className="font-medium text-primary truncate">{p.name}</span>
              </div>
              <span className="text-secondary shrink-0">{formatNumber(p.tokens)}</span>
            </div>
            <div className="h-2 w-full bg-surface-inset rounded-full overflow-hidden">
              <div
                className="h-full bg-data-secondary rounded-full"
                style={{ width: `${(p.tokens / maxTokens) * 100}%` }}
              />
            </div>
            {p.estimated_cost_usd !== null && (
              <p className="text-xs text-tertiary">
                ${p.estimated_cost_usd.toFixed(2)} cost estimate · {p.thread_count} threads
              </p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}
