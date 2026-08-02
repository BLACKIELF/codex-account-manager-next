import { Archive, CalendarClock, CircleDashed, CircleDot, ClipboardList, Clock3 } from 'lucide-react';
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
  const isEmpty = itemCount === 0;

  return (
    <section className="glass-panel p-4 sm:p-5 space-y-4" aria-label="Codex task board" aria-live="polite">
      <PanelHeading summary={taskBoardSummary(taskBoard, itemCount)} />
      {isEmpty ? (
        <div className="task-board-empty flex items-start gap-2 rounded-xl border border-theme bg-surface-inset px-3 py-2.5">
          <CircleDashed size={15} aria-hidden="true" className="mt-0.5 shrink-0 text-tertiary" />
          <div>
            <p className="text-sm text-secondary">No trusted task records yet.</p>
            <p className="mt-1 text-xs text-tertiary">
              This board shows only non-subagent local activity, explicit archives, and validated active automations.
            </p>
          </div>
        </div>
      ) : null}
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
                <div className="task-column-empty flex items-center gap-2 py-3 text-xs text-tertiary">
                  <CircleDashed size={13} aria-hidden="true" />
                  <span>No records</span>
                </div>
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
                      {item.detail || factualTime(item) ? (
                        <div className="task-card-meta mt-2 flex min-w-0 items-center gap-2 text-xs">
                          {item.detail ? <span className="min-w-0 truncate text-secondary">{item.detail}</span> : null}
                          {factualTime(item) ? (
                            <time className="shrink-0 text-tertiary">{factualTime(item)}</time>
                          ) : null}
                        </div>
                      ) : null}
                      <footer className="task-card-footer mt-2 pt-2 border-t border-theme/30">
                        <span
                          className={`state-badge inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] ${stateBadgeClass(item)}`}
                        >
                          {(() => {
                            const StateIcon = stateIcon(item);
                            return <StateIcon size={12} aria-hidden="true" />;
                          })()}
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

function PanelHeading({ summary }: { summary?: string | null }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <div className="flex min-w-0 items-center gap-2">
        <ClipboardList size={16} aria-hidden="true" />
        <h3 className="text-sm font-semibold text-primary">Tasks</h3>
      </div>
      {summary ? <p className="task-board-summary shrink-0 text-right text-xs text-secondary tabular-nums">{summary}</p> : null}
    </div>
  );
}

function taskBoardSummary(taskBoard: TaskBoard, itemCount: number): string {
  const refreshedAt = formatTaskTime(taskBoard.refreshed_at);
  return refreshedAt ? `${itemCount} items · Refreshed ${refreshedAt}` : `${itemCount} items`;
}

function formatTaskTime(value: number): string | null {
  if (!Number.isFinite(value)) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
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

function stateIcon(item: TaskItem) {
  switch (item.display_state) {
    case 'recentlyActive':
      return Clock3;
    case 'continueLater':
      return CircleDot;
    case 'archived':
      return Archive;
    case 'scheduled':
      return CalendarClock;
    default:
      return ClipboardList;
  }
}

function stateBadgeClass(item: TaskItem): string {
  switch (item.display_state) {
    case 'recentlyActive':
      return 'border-status-warn/30 bg-status-warn/12 text-status-warn';
    case 'scheduled':
      return 'border-accent/25 bg-accent/10 text-accent';
    case 'continueLater':
    case 'archived':
    default:
      return 'border-theme bg-surface-inset text-secondary';
  }
}

function factualTime(item: TaskItem): string | null {
  if (item.updated_at == null || !Number.isFinite(item.updated_at)) return null;
  const label = item.display_state === 'archived' ? 'Archived' : 'Updated';
  return `${label} ${new Date(item.updated_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}
