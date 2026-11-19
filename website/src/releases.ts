// Releases for the news page and the version in the header (ADR-0041): the notes
// come from app/assets/whats_new.json (the same "What's new" the app shows after an
// update), the release dates from CHANGELOG.md. Plain functions without Astro, so
// they are tested with `node --test` (releases.test.ts).

export type Lang = 'de' | 'en';

export type WhatsNew = Record<string, Partial<Record<Lang, string[]>>>;

export interface Release {
  version: string;
  /** Release date as YYYY-MM-DD, from the version's CHANGELOG.md section. */
  date: string;
  notes: string[];
}

const versionPattern = /^\d+\.\d+\.\d+$/;

/** Compares X.Y.Z versions numerically; negative if a is older than b. */
export function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] - pb[i];
  }
  return 0;
}

/** The release date of every version in CHANGELOG.md (`## [X.Y.Z] - YYYY-MM-DD`). */
export function changelogDates(changelog: string): Map<string, string> {
  const dates = new Map<string, string>();
  for (const m of changelog.matchAll(/^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})\s*$/gm)) {
    dates.set(m[1], m[2]);
  }
  return dates;
}

/**
 * The releases with notes in `lang`, newest first. Fails (and with it the website
 * build) when a version is malformed or has no released CHANGELOG.md section, so
 * the page never shows a version that is not released.
 */
export function releases(whatsNew: WhatsNew, changelog: string, lang: Lang): Release[] {
  const dates = changelogDates(changelog);
  const result = Object.entries(whatsNew).map(([version, notes]) => {
    if (!versionPattern.test(version)) {
      throw new Error(`whats_new.json: "${version}" is not a version X.Y.Z`);
    }
    const date = dates.get(version);
    if (!date) {
      throw new Error(`whats_new.json: version ${version} has no "## [${version}] - YYYY-MM-DD" section in CHANGELOG.md`);
    }
    const list = notes[lang];
    if (!Array.isArray(list)) {
      throw new Error(`whats_new.json: version ${version} has no "${lang}" notes`);
    }
    return { version, date, notes: list };
  });
  if (result.length === 0) throw new Error('whats_new.json: no version');
  return result.sort((a, b) => compareVersions(b.version, a.version));
}

/** A date YYYY-MM-DD as "19. November 2026" (de-CH) or "19 November 2026" (en). */
export function formatDate(date: string, lang: Lang): string {
  return new Intl.DateTimeFormat(lang === 'de' ? 'de-CH' : 'en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${date}T00:00:00Z`));
}
