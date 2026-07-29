import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const panel = readFileSync(new URL('../src/components/TaskBoardPanel.tsx', import.meta.url), 'utf8');
const dashboardHome = readFileSync(new URL('../src/components/DashboardHome.tsx', import.meta.url), 'utf8');

test('Dashboard task tab renders the sanitized task board panel and its empty state', () => {
  assert.match(dashboardHome, /TaskBoardPanel/);
  assert.match(dashboardHome, /taskBoard=\{snapshot\?\.task_board \?\? null\}/);
  assert.match(panel, /No trusted task records yet/);
  assert.match(panel, /Recent activity/);
  assert.match(panel, /Archived/);
});

test('Task board panel does not render raw status or technical task identifiers', () => {
  assert.doesNotMatch(panel, /raw_status/);
  assert.doesNotMatch(panel, /item\.code/);
  assert.doesNotMatch(panel, /item\.thread_id/);
});
