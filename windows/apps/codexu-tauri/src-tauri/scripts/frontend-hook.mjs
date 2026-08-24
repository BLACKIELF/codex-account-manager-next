import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const mode = process.argv[2];
if (!mode || (mode !== 'build' && mode !== 'dev')) {
  console.error('Usage: node ./scripts/frontend-hook.mjs [build|dev]');
  process.exit(1);
}

const isTruthyFlag = (value) => {
  if (!value) {
    return false;
  }

  return ['1', 'true', 'TRUE', 'True'].includes(value);
};

const hasNoDevServerFlag =
  process.argv.includes('--no-dev-server') ||
  process.argv.includes('--noDevServer') ||
  isTruthyFlag(process.env.NO_DEV_SERVER) ||
  isTruthyFlag(process.env.TAURI_NO_DEV_SERVER) ||
  isTruthyFlag(process.env.CARGO_TAURI_NO_DEV_SERVER) ||
  isTruthyFlag(process.env.TAURI_SKIP_DEV_SERVER);

if (mode === 'dev' && hasNoDevServerFlag) {
  console.log('[frontend-hook] Skipping frontend dev server because no-dev-server mode is enabled.');
  process.exit(0);
}

let currentDir = process.cwd();
let webDir = '';

const hasWebPackage = (dir) => {
  const candidate = path.join(dir, 'web', 'package.json');
  const tauriConf = path.join(dir, 'src-tauri', 'tauri.conf.json');
  return fs.existsSync(candidate) && fs.existsSync(tauriConf);
};

while (currentDir && currentDir !== path.parse(currentDir).root) {
  if (hasWebPackage(currentDir)) {
    webDir = path.join(currentDir, 'web');
    break;
  }
  currentDir = path.dirname(currentDir);
}

if (!webDir) {
  console.error('Could not locate project web workspace from:', process.cwd());
  process.exit(1);
}

const command = `npm run ${mode}`;
const result = spawnSync(command, {
  cwd: webDir,
  stdio: 'inherit',
  shell: true,
  env: process.env,
});

if (result.error) {
  throw result.error;
}

process.exit(result.status ?? 0);
