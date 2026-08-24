import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import ts from 'typescript';

const messagesPath = new URL('../src/i18n/messages.ts', import.meta.url);

async function loadMessagesModule() {
  assert.equal(existsSync(messagesPath), true, 'typed i18n message table should exist');
  const source = readFileSync(messagesPath, 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  return import(`data:text/javascript,${encodeURIComponent(output)}`);
}

test('auto resolves Chinese browser languages and English is the fallback', async () => {
  const { resolveInterfaceLanguage } = await loadMessagesModule();
  assert.equal(resolveInterfaceLanguage('auto', 'zh-CN'), 'zh-Hans');
  assert.equal(resolveInterfaceLanguage('auto', 'zh-Hant-TW'), 'zh-Hans');
  assert.equal(resolveInterfaceLanguage('auto', 'en-US'), 'en');
});

test('manual Chinese and English preferences override browser language', async () => {
  const { resolveInterfaceLanguage } = await loadMessagesModule();
  assert.equal(resolveInterfaceLanguage('zh-Hans', 'en-US'), 'zh-Hans');
  assert.equal(resolveInterfaceLanguage('en', 'zh-CN'), 'en');
});

test('core Dashboard, Tasks, and Settings messages switch with the resolved language', async () => {
  const { getMessages } = await loadMessagesModule();
  const zh = getMessages('zh-Hans');
  const en = getMessages('en');

  assert.equal(zh.dashboard.tabs.tasks, '任务');
  assert.equal(en.dashboard.tabs.tasks, 'Tasks');
  assert.equal(zh.tasks.title, '任务');
  assert.equal(en.tasks.title, 'Tasks');
  assert.equal(zh.settings.title, '设置');
  assert.equal(en.settings.title, 'Settings');
});
