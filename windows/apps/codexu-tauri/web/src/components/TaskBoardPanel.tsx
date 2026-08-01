import { Archive, CalendarClock, CircleDot, ClipboardList, Clock3 } from 'lucide-react';
import type { TaskBoard, TaskItem } from '../types/models';

interface TaskBoardPanelProps {
  taskBoard: TaskBoard | null;
}

const COLUMN_ICONS = {
  active: CircleDot,
  pending: Clock3,
  scheduled: CalendarClock,
  done: Archive,
} as const;

export function TaskBoardPanel({ taskBoard }: TaskBoardPanelProps) {
  if (!taskBoard) {
    return (
      <section className="glass-panel p-4 sm:p-5" aria-live="polite">
        <PanelHeading />
        <p className="text-sm text-secondary mt-2">
          Task status is unavailable until Codex provides local state records.
        </p>
      </section>
    );
  }

  const itemCount = taskBoard.columns.reduce((sum, column) => sum + column.items.length, 0);
  if (itemCount === 0) {
    return (
      <section className="glass-panel p-4 sm:p-5" aria-live="polite">
        <PanelHeading />
        <p className="text-sm text-secondary mt-2">No trusted task records yet.</p>
        <p className="text-xs text-tertiary mt-1">
          This board shows only non-subagent local activity, explicit archives, and validated active automations.
        </p>
      </section>
    );
  }

  return (
    <section className="glass-panel p-4 sm:p-5 space-y-4" aria-label="Codex task board">
      <PanelHeading />
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
        {taskBoard.columns.map((column) => {
          const Icon = COLUMN_ICONS[column.id as keyof typeof COLUMN_ICONS] ?? ClipboardList;
          return (
            <section key={column.id} className="rounded-2xl border border-theme bg-surface-inset p-3 min-h-40">
              <div className="flex items-center justify-between gap-2 mb-3">
                <div className="flex items-center gap-2 min-w-0">
                  <Icon size={15} aria-hidden="true" className="text-secondary shrink-0" />
                  <h4 className="text-sm font-semibold text-primary truncate">{column.title}</h4>
                </div>
                <span className="text-xs text-tertiary tabular-nums">{column.count}</span>
              </div>
              {column.items.length === 0 ? (
                <p className="text-xs text-tertiary py-2">No records</p>
              ) : (
                <div className="space-y-2">
                  {column.items.map((item) => (
                    <article key={item.id} className="rounded-xl border border-theme bg-surface-elevated p-3">
                      <div className="min-w-0">
                        <p
                          className="task-card-title text-sm font-medium text-primary leading-snug min-w-0 break-words min-h-10"
                          title={item.title}
                        >
                          {item.title}
                        </p>
                      </div>
                      {item.detail ? <p className="text-xs text-secondary mt-2 truncate">{item.detail}</p> : null}
                      {factualTime(item) ? <p className="text-xs text-tertiary mt-1 truncate">{factualTime(item)}</p> : null}
                      <footer className="task-card-footer mt-2 pt-2 border-t border-theme/30">
                        <span className="inline-flex items-center rounded-full border border-theme bg-surface-inset px-2 py-0.5 text-[11px] text-secondary">
                          {stateLabel(item)}
                        </span>
                      </footer>
                    </article>
                  ))}
                </div>
              )}
            </section>
          );
        })}
      </div>
    </section>
  );
}

function PanelHeading() {
  return (
    <div className="flex items-center gap-2">
      <ClipboardList size={16} aria-hidden="true" />
      <h3 className="text-sm font-semibold text-primary">Tasks</h3>
    </div>
  );
}

function stateLabel(item: TaskItem): string {
  switch (item.display_state) {
    case 'recentlyActive':
      return 'Recent activity';
    case 'continueLater':
      return 'To continue';
    case 'archived':
      return 'Archived';
    case 'scheduled':
      return 'Scheduled';
    default:
      return 'Recorded';
  }
}

function factualTime(item: TaskItem): string | null {
  if (item.updated_at == null || !Number.isFinite(item.updated_at)) return null;
  const label = item.display_state === 'archived' ? 'Archived' : 'Updated';
  return `${label} ${new Date(item.updated_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}
