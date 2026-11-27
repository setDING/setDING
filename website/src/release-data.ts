// The repository's releases for the website (ADR-0041): built from the checkout
// the site is built from, so a deploy from the tag (make server-release) shows
// that release.
import whatsNew from '../../app/assets/whats_new.json';
import changelog from '../../CHANGELOG.md?raw';
import { releases, type Lang, type Release } from './releases.ts';

export const releasesFor = (lang: Lang): Release[] => releases(whatsNew, changelog, lang);

/** The current (newest) released version. */
export const currentVersion: string = releasesFor('en')[0].version;

export const releaseUrl = (version: string): string =>
  `https://github.com/setDING/setDING/releases/tag/v${version}`;

export const changelogUrl = 'https://github.com/setDING/setDING/blob/main/CHANGELOG.md';
