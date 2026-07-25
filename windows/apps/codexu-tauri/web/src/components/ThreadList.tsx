import { Archive, Clock, Cpu } from 'lucide-react';
import type { LocalThread } from '../types/models';

interface ThreadListProps {
  threads: LocalThread[];
}

export function ThreadList({ threads }: ThreadListProps) {
  if (threads.length === 0) {
    return (
      <div className="glass-panel p-4 sm:p-5">
        <h3 className="text-sm font-semibold text-primary mb-4">Recent Threads</h3>
        <p className="text-secondary text-sm">No threads found.</p>
      </div>
    );
  }

  const sorted = [...threads].sort((a, b) => {
    const ta = a.updated_at ?? 0;
    const tb = b.updated_at ?? 0;
    return tb - ta;
  });

  return (
    <div className="glass-panel p-4 sm:p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-primary">Recent Threads</h3>
        <span className="text-xs text-tertiary">{threads.length} total</span>
      </div>
      <div className="space-y-2 max-h-80 overflow-auto">
        {sorted.slice(0, 20).map((t) => (
          <div
            key={t.id}
            className="flex items-center justify-between gap-3 p-3 rounded-xl glass-input hover:border-theme/80 transition-colors"
          >
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <p className="text-sm font-medium text-primary truncate">{t.title}</p>
                {t.archived && (
                  <span className="inline-flex items-center gap-1 chip-like bg-status-warn/12 text-status-warn border-status-warn/30">
                    <Archive size={10} /> Archived
                  </span>
                )}
              </div>
              <p className="text-xs text-tertiary truncate mt-0.5">{shortPath(t.cwd)}</p>
            </div>
            <div className="flex items-center gap-3 text-xs text-secondary shrink-0">
              {t.model && (
                <span className="inline-flex items-center gap-1">
                  <Cpu size={12} /> {t.model}
                </span>
              )}
              {t.updated_at && (
                <span className="inline-flex items-center gap-1">
                  <Clock size={12} /> {formatTime(t.updated_at)}
                </span>
              )}
              <span className="font-medium text-primary">{formatNumber(t.tokens)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function shortPath(path: string): string {
  if (!path) return 'Unknown';
  const normalized = path.replace(/\\/g, '/');
  const parts = normalized.split('/').filter(Boolean);
  return parts.slice(-2).join('/') || normalized;
}

function formatTime(ts: number): string {
  const date = new Date(ts);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
  if (diffHrs < 1) return 'now';
  if (diffHrs < 24) return `${diffHrs}h ago`;
  const diffDays = Math.floor(diffHrs / 24);
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString();
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}
