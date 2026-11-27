// Tests for releases.ts, run by tool/build-site.sh with `node --test` before the build.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { changelogDates, compareVersions, formatDate, releases } from './releases.ts';

const changelog = `# Changelog

## [Unreleased]

## [0.10.0] - 2026-11-20

### Added

- Something

## [0.9.1] - 2026-11-01

[0.10.0]: https://github.com/setDING/setDING/compare/v0.9.1...v0.10.0
`;

test('compares versions numerically', () => {
  assert.ok(compareVersions('0.10.0', '0.9.1') > 0);
  assert.ok(compareVersions('0.9.1', '0.10.0') < 0);
  assert.equal(compareVersions('1.2.3', '1.2.3'), 0);
});

test('reads the release dates and skips Unreleased', () => {
  assert.deepEqual(
    [...changelogDates(changelog)],
    [
      ['0.10.0', '2026-11-20'],
      ['0.9.1', '2026-11-01'],
    ],
  );
});

test('lists the releases newest first in the requested language', () => {
  const list = releases(
    { '0.9.1': { de: [], en: [] }, '0.10.0': { de: ['Neu'], en: ['New'] } },
    changelog,
    'en',
  );
  assert.deepEqual(list, [
    { version: '0.10.0', date: '2026-11-20', notes: ['New'] },
    { version: '0.9.1', date: '2026-11-01', notes: [] },
  ]);
});

test('fails on a version without a released changelog section', () => {
  assert.throws(() => releases({ '0.11.0': { de: [], en: [] } }, changelog, 'de'), /0\.11\.0/);
});

test('fails on a malformed version, missing notes and an empty file', () => {
  assert.throws(() => releases({ 'v0.10.0': { de: [], en: [] } }, changelog, 'de'), /not a version/);
  assert.throws(() => releases({ '0.10.0': { en: [] } }, changelog, 'de'), /"de"/);
  assert.throws(() => releases({}, changelog, 'de'), /no version/);
});

test('formats dates per language', () => {
  assert.equal(formatDate('2026-11-19', 'de'), '19. November 2026');
  assert.equal(formatDate('2026-11-19', 'en'), '19 November 2026');
});

test('the repository files give the released version of pubspec.yaml first', () => {
  const root = new URL('../../', import.meta.url);
  const whatsNew = JSON.parse(readFileSync(new URL('app/assets/whats_new.json', root), 'utf8'));
  const log = readFileSync(new URL('CHANGELOG.md', root), 'utf8');
  const pubspec = readFileSync(new URL('app/pubspec.yaml', root), 'utf8');
  const match = /^version:\s*(\d+\.\d+\.\d+)(-\S+)?/m.exec(pubspec);
  // A pre-release (1.3.0-beta.1) has no notes of its own; the site shows the
  // last final release (ADR-0069).
  if (match?.[2]) return;
  const version = match?.[1];
  for (const lang of ['de', 'en'] as const) {
    assert.equal(releases(whatsNew, log, lang)[0].version, version);
  }
});
