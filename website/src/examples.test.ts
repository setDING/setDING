// Tests for the example songs on the website (#923), run by
// tool/build-site.sh with `node --test` before the build: every download
// link under /examples/ and every <ExampleSong> has its files in
// docs/examples, and every song archive there is shown on a page.
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { exampleFiles } from './examples-integration.mjs';

const examples = new URL('../../docs/examples/', import.meta.url).pathname;
const docs = new URL('content/docs/', import.meta.url).pathname;

function pages(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory()
      ? pages(join(dir, e.name))
      : /\.mdx?$/.test(e.name)
        ? [readFileSync(join(dir, e.name), 'utf8')]
        : [],
  );
}

const content = pages(docs).join('\n');
const links = [...content.matchAll(/\/examples\/([^)\s"'>]+)/g)].map((m) => m[1]);
const songs = [...content.matchAll(/<ExampleSong name="([^"]+)"/g)].map((m) => m[1]);

test('every /examples/ link is served', async () => {
  const served = await exampleFiles();
  assert.ok(links.length > 0);
  for (const link of links) assert.ok(served.includes(link), link);
});

test('every example song has its source and its song archive', async () => {
  const served = await exampleFiles();
  assert.ok(songs.length > 0);
  for (const name of songs) {
    assert.ok(existsSync(join(examples, `${name}.cho`)), `${name}.cho`);
    assert.ok(served.includes(`${name}.setDING.zip`), `${name}.setDING.zip`);
  }
});

test('every song archive is shown on a page', async () => {
  for (const file of await exampleFiles()) {
    if (!file.endsWith('.setDING.zip')) continue;
    assert.ok(songs.includes(file.replace('.setDING.zip', '')), file);
  }
});
