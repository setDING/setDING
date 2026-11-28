// Tests for google-play.ts, run by tool/build-site.sh with `node --test` before the build.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { googlePlayAppId, googlePlayUrl } from './google-play.ts';

test('the Google Play link opens the release build of the app', () => {
  const gradle = readFileSync(
    new URL('../../app/android/app/build.gradle.kts', import.meta.url),
    'utf8',
  );
  const release = /else\s*->\s*"([^"]+)"/.exec(gradle)?.[1];
  assert.equal(googlePlayAppId, release);
  assert.equal(
    googlePlayUrl,
    'https://play.google.com/store/apps/details?id=app.setding',
  );
});
