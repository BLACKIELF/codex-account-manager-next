import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const reader = readFileSync(new URL('../../../../crates/codexu-core/src/readers/codex_task_board.rs', import.meta.url), 'utf8');

test('Codex thread task titles follow the macOS session metadata contract', () => {
  assert.match(reader, /normalize_task_title/);
  assert.match(reader, /record\.title\.as_deref\(\)/);
  assert.match(reader, /record\.preview\.as_deref\(\)/);
  assert.match(reader, /thread_id: Some\(record\.id\.clone\(\)\)/);
  assert.match(reader, /name: name\.map\(str::to_owned\)/);
  assert.doesNotMatch(reader, /THREAD_ACTIVITY_TITLE/);
  assert.doesNotMatch(reader, /title: "Local Codex automation"/);
});
