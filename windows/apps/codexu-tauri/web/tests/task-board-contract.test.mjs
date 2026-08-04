import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const panel = readFileSync(new URL('../src/components/TaskBoardPanel.tsx', import.meta.url), 'utf8');
const dashboardHome = readFileSync(new URL('../src/components/DashboardHome.tsx', import.meta.url), 'utf8');

test('Dashboard task tab renders the sanitized task board panel and its empty state', () => {
  assert.match(dashboardHome, /TaskBoardPanel/);
  assert.match(dashboardHome, /taskBoard=\{snapshot\?\.task_board \?\? null\}/);
  assert.match(panel, /tasks\.empty/);
  assert.match(panel, /tasks\.recentActivity/);
  assert.match(panel, /tasks\.archived/);
  assert.match(panel, /useI18n/);
});

test('Task board panel does not render raw status or technical task identifiers', () => {
  assert.doesNotMatch(panel, /raw_status/);
  assert.doesNotMatch(panel, /item\.code/);
  assert.doesNotMatch(panel, /item\.thread_id/);
});

test('Task board keeps the status columns visible for an available but empty board', () => {
  assert.match(panel, /task-board-empty/);
  assert.match(panel, /task-column-empty/);
  assert.match(panel, /CircleDashed/);
  assert.doesNotMatch(panel, /if \(itemCount === 0\) \{[\s\S]*?return \(/);
});

test('Task cards use a compact metadata row and an icon-backed state badge', () => {
  assert.match(panel, /task-card-meta/);
  assert.match(panel, /<time className="[^"]*shrink-0/);
  assert.match(panel, /state-badge/);
  assert.match(panel, /stateIcon/);
  assert.match(panel, /aria-hidden="true"/);
});

test('Task board heading exposes a safe aggregate refresh summary', () => {
  assert.match(panel, /task-board-summary/);
  assert.match(panel, /itemCount/);
  assert.match(panel, /taskBoard\.refreshed_at/);
});

test('Task board cards reserve stable title height and keep state in card footer', () => {
  const cardMatch = panel.match(/<article key=\{item\.id\}[\s\S]*?<\/article>/);
  assert.ok(cardMatch, 'Expected an article card block in component source');
  const cardBody = cardMatch[0];
  const normalizedCard = cardBody.replace(/\s+/g, ' ');

  assert.match(cardBody, /task-card-title/);
  assert.match(cardBody, /task-card-footer/);
  assert.doesNotMatch(normalizedCard, /flex items-start justify-between gap-2/);

  const titleStart = cardBody.indexOf('task-card-title');
  assert.ok(titleStart >= 0, 'Expected task-card-title in card');
  const titleClose = cardBody.indexOf('</p>', titleStart);
  assert.ok(titleClose > titleStart, 'Expected closing title paragraph');
  const titleSegment = cardBody.slice(titleStart - 80, titleClose + 4);

  assert.match(titleSegment, /break-words/);
  assert.match(titleSegment, /min-h-10/);
  assert.match(titleSegment, /min-w-0/);
  assert.doesNotMatch(titleSegment, /line-clamp/);
  assert.doesNotMatch(titleSegment, /truncate/);
  assert.doesNotMatch(titleSegment, /text-ellipsis/);
  assert.ok(!titleSegment.includes('{stateLabel(item)}'), 'Title block should not include stateLabel');
  assert.ok(titleSegment.includes('{item.title}'), 'Title segment should include item.title');

  const stateCount = (cardBody.match(/stateLabel\(item,\s*t\)/g) || []).length;
  assert.equal(stateCount, 1, 'stateLabel should appear once in each card');

  const footerStart = cardBody.indexOf('task-card-footer');
  assert.ok(footerStart > titleStart, 'Footer should follow title');
  const footerClose = cardBody.indexOf('</footer>', footerStart);
  assert.ok(footerClose > footerStart, 'Expected closing footer tag');
  const footerSegment = cardBody.slice(footerStart - 80, footerClose + 9);
  assert.ok(footerSegment.includes('{stateLabel(item, t)}'), 'State label should be in footer');
  assert.match(footerSegment, /task-card-footer/);

  assert.match(normalizedCard, /task-card-meta mt-2 flex min-w-0 items-center gap-2 text-xs/);
  assert.match(normalizedCard, /item\.detail \? <span className=\"min-w-0 truncate text-secondary\">\{item\.detail\}<\/span> : null/);
  assert.match(normalizedCard, /factualTime\(item, t\) \? \( <time className=\"shrink-0 text-tertiary\">\{factualTime\(item, t\)\}<\/time> \) : null/);
  assert.match(normalizedCard, /<footer className=\"[^\"]*\">[\s\S]*{stateLabel\(item, t\)}[\s\S]*<\/footer>/);
});
