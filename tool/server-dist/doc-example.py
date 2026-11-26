#!/usr/bin/env python3
"""Prints an example file from the self-hosting documentation (ADR-0063 §5).

    doc-example.py <page> <title>     e.g. doc-example.py docker docker-compose.yml

<page> is a page of website/src/content/docs/self-hosting/ (without .mdx);
<title> the title of its code block (```lang title="<title>"). The block must
be the same on the German and the English page, so both languages show what
the tests run. Its indentation inside a list item is removed.
"""

import pathlib
import re
import sys
import textwrap

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOCS = ROOT / 'website' / 'src' / 'content' / 'docs'


def block(path, title):
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(
        r'^([ \t]*)```[a-z]*[ \t]+title="' + re.escape(title) + r'"[ \t]*\n(.*?)^\1```[ \t]*$',
        re.M | re.S)
    found = pattern.findall(text)
    if len(found) != 1:
        sys.exit(f'doc-example: {path}: expected one code block titled "{title}", found {len(found)}')
    return textwrap.dedent(found[0][1])


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    page, title = sys.argv[1:]
    de = block(DOCS / 'self-hosting' / f'{page}.mdx', title)
    en = block(DOCS / 'en' / 'self-hosting' / f'{page}.mdx', title)
    if de != en:
        sys.exit(f'doc-example: "{title}" differs between the German and the English page {page}.mdx')
    sys.stdout.write(de)


if __name__ == '__main__':
    main()
