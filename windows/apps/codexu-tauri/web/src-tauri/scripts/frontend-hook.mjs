import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const hookPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../../src-tauri/scripts/frontend-hook.mjs'
);

const result = spawnSync(process.execPath, [hookPath, ...process.argv.slice(2)], {
  stdio: 'inherit',
});

if (result.error) {
  throw result.error;
}

process.exit(result.status ?? 0);
