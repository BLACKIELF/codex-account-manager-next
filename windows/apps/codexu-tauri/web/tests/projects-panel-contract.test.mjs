import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const boardPath = new URL('../src/components/ProjectBoard.tsx', import.meta.url);
const panelPath = new URL('../src/components/ProjectsPanel.tsx', import.meta.url);
const homePath = new URL('../src/components/DashboardHome.tsx', import.meta.url);

test('keeps Projects focused on the macOS ranking and activity hierarchy', async () => {
  const [board, panel, home] = await Promise.all([
    readFile(boardPath, 'utf8'),
    readFile(panelPath, 'utf8'),
    readFile(homePath, 'utf8'),
  ]);

  assert.match(board, /type ProjectTimeframe\s*=\s*'recent'\s*\|\s*'all'/);
  assert.match(board, /useState<ProjectTimeframe>\('recent'\)/);
  assert.match(board, /recent_projects/);
  assert.match(board, /all_projects/);
  assert.match(board, /slice\(0, 8\)/);
  assert.match(board, /last_active_at/);
  assert.match(board, /source_quality/);
  assert.match(board, /No project records/);
  assert.doesNotMatch(board, /full_path/);

  assert.match(panel, /ProjectBoard/);
  assert.match(panel, /ProjectActivityOverview/);
  assert.match(panel, /projectBoard/);

  assert.match(home, /<ProjectsPanel\s+projectBoard=\{usage\?\.project_board \?\? null\}/);
  assert.doesNotMatch(home, /<ProjectsPanel[\s\S]*projects=\{usage\?\.project_board\?\.recent_projects/);
});
