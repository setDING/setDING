// Tests for the help links of the app (#993), run by tool/build-site.sh with
// `node --test` before the build: every page of `DocsPage` in
// app/lib/ui/widgets/docs_link.dart exists in every language folder the app
// links to, so renaming or moving a page here cannot leave a dead help
// button in the app.
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(
  new URL('../../app/lib/ui/widgets/docs_link.dart', import.meta.url),
  'utf8',
);
const docs = new URL('content/docs/', import.meta.url).pathname;

/** The paths of the `DocsPage` enum, e.g. `bands/roles`. */
function pagePaths(): string[] {
  const body = source.match(/enum DocsPage \{([\s\S]*?);/)?.[1];
  assert.ok(body, 'enum DocsPage not found');
  return [...body.matchAll(/\w+\('([^']+)'\)/g)].map((m) => m[1]);
}

/** The language folders of `docsSiteLanguages`, e.g. `''` and `'en/'`. */
function languageFolders(): string[] {
  const map = source.match(/docsSiteLanguages = \{([^}]*)\}/)?.[1];
  assert.ok(map, 'docsSiteLanguages not found');
  return [...map.matchAll(/'\w+': '([^']*)'/g)].map((m) => m[1]);
}

test('the app links to pages and languages', () => {
  assert.ok(pagePaths().length > 0);
  assert.deepEqual(languageFolders(), ['', 'en/']);
});

test('every page of the app exists in every language', () => {
  for (const folder of languageFolders()) {
    for (const path of pagePaths()) {
      const base = `${docs}${folder}${path}`;
      assert.ok(
        existsSync(`${base}.md`) || existsSync(`${base}.mdx`),
        `the app links to /${folder}${path}/, which has no page in website/src/content/docs`,
      );
    }
  }
});
