import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const rootDir = '/Users/wb/work/PhantomKnob';

test('Homepage and documentation reflect 2 pro slots policy', async (t) => {
  const indexZh = fs.readFileSync(path.join(rootDir, 'index_zh.html'), 'utf8');
  const indexEn = fs.readFileSync(path.join(rootDir, 'index.html'), 'utf8');
  const readmeZh = fs.readFileSync(path.join(rootDir, 'README_zh.md'), 'utf8');
  const readmeEn = fs.readFileSync(path.join(rootDir, 'README.md'), 'utf8');

  await t.test('index_zh.html has no 5-slot references and accurately describes 2 pro slots', () => {
    assert.doesNotMatch(indexZh, /5\s*款专业/, 'index_zh.html should not contain "5 款专业"');
    assert.doesNotMatch(indexZh, /5\s*个专业/, 'index_zh.html should not contain "5 个专业"');
    assert.doesNotMatch(indexZh, /5\s*槽位/, 'index_zh.html should not contain "5 槽位"');
    assert.doesNotMatch(indexZh, /第\s*6\s*款/, 'index_zh.html should not contain "第 6 款"');

    assert.match(indexZh, /2\s*款专业创作 App/, 'index_zh.html should mention "2 款专业创作 App"');
    assert.match(indexZh, /2\s*个专业创作 App 槽位不够用怎么办/, 'index_zh.html FAQ should ask about 2 pro app slots');
    assert.match(indexZh, /第\s*3\s*款及以上/, 'index_zh.html FAQ should mention 3rd app standby policy');
  });

  await t.test('index.html has no 5-slot references and accurately describes 2 pro slots', () => {
    assert.doesNotMatch(indexEn, /5\s*pro app slots/i, 'index.html should not contain "5 pro app slots"');
    assert.doesNotMatch(indexEn, /5\s*pro creative apps/i, 'index.html should not contain "5 pro creative apps"');
    assert.doesNotMatch(indexEn, /5-slot cap/i, 'index.html should not contain "5-slot cap"');

    assert.match(indexEn, /2\s*pro app slots/i, 'index.html should describe 2 pro app slots');
    assert.match(indexEn, /2\s*pro creative apps/i, 'index.html should mention 2 pro creative apps');
    assert.match(indexEn, /What if 2 pro app slots aren't enough\?/i, 'index.html FAQ should ask about 2 pro app slots');
  });

  await t.test('README_zh.md has no 5-slot references and accurately describes 2 pro slots', () => {
    assert.doesNotMatch(readmeZh, /5\s*款专业/, 'README_zh.md should not contain "5 款专业"');
    assert.doesNotMatch(readmeZh, /5\s*个专业/, 'README_zh.md should not contain "5 个专业"');
    assert.doesNotMatch(readmeZh, /第\s*6\s*款/, 'README_zh.md should not contain "第 6 款"');

    assert.match(readmeZh, /2\s*款（可随时轮换）/, 'README_zh.md matrix should state 2 apps');
    assert.match(readmeZh, /2\s*个专业 App 槽位/, 'README_zh.md FAQ should state 2 pro app slots');
  });

  await t.test('README.md has no 5-slot references and accurately describes 2 pro slots', () => {
    assert.doesNotMatch(readmeEn, /5\s*customizable professional app slots/i, 'README.md should not contain 5 slots');
    assert.doesNotMatch(readmeEn, /5\s*apps\s*\(Hot-swappable\)/i, 'README.md matrix should not state 5 apps');
    assert.doesNotMatch(readmeEn, /5\s*Pro App slots/i, 'README.md FAQ should not ask about 5 slots');

    assert.match(readmeEn, /2\s*customizable professional app slots/i, 'README.md should mention 2 slots');
    assert.match(readmeEn, /2\s*apps\s*\(Hot-swappable\)/i, 'README.md matrix should state 2 apps');
    assert.match(readmeEn, /2\s*Pro App slots/i, 'README.md FAQ should state 2 pro app slots');
  });
});
