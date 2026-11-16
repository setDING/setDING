#!/usr/bin/env python3
"""Move RealChord's issues and pull requests from Forgejo to GitHub.

Runbook: docs/development/github-migration.md (issue #116, ADR-0010).

Subcommands (run in this order):

  export    Read labels, milestones, issues, pull requests and comments from
            Forgejo into EXPORT_DIR/forgejo.json (read-only on Forgejo).
  rules     Print the replacement rules for `git filter-repo --replace-text`
            and `--replace-message` (used by history.sh).
  plan      Dry run: show what `import` would create on GitHub and check that
            no reference to the Forgejo instance survives. Changes nothing.
  import    Create labels, milestones and one GitHub issue per Forgejo number,
            in number order, so `#n` keeps pointing to the same item. Pull
            requests become closed issues with the label `forgejo:pull-request`.
            Resumable: progress is kept in EXPORT_DIR/import-state.json.
  settings  Set the GitHub repository settings (squash merge only, delete
            branch after merge, no wiki/projects).
  verify    Compare GitHub with the export (numbers, titles, states) and scan
            all GitHub issue texts for references to the Forgejo instance.

Tokens: FORGEJO_TOKEN (default: the `fj` login in
~/.local/share/forgejo-cli/keys.json) and GITHUB_TOKEN (default: `gh auth token`).

No text written to GitHub may reference the Forgejo instance: every text goes
through `clean()`, and `plan`/`import`/`verify` fail if FORBIDDEN still matches.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPORT_DIR = Path(os.environ.get("EXPORT_DIR", ROOT / ".github-migration"))


def _forgejo_from_origin() -> tuple[str, str]:
    """Host and owner/repo of the Forgejo remote `origin`.

    Deliberately not hard-coded: the repository (and with it this script) must
    not name the Forgejo instance once it is on GitHub. After the move, set
    FORGEJO_HOST and FORGEJO_REPO explicitly.
    """
    try:
        url = subprocess.run(["git", "-C", str(ROOT), "remote", "get-url", "origin"], check=True,
                             capture_output=True, text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "", ""
    m = re.match(r"^(?:\w+://)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[:/](.+?)(?:\.git)?/?$", url)
    if not m or m.group(1) == "github.com":
        return "", ""
    return m.group(1), m.group(2)


_ORIGIN_HOST, _ORIGIN_REPO = _forgejo_from_origin()
FORGEJO_HOST = os.environ.get("FORGEJO_HOST") or _ORIGIN_HOST
FORGEJO_REPO = os.environ.get("FORGEJO_REPO") or _ORIGIN_REPO
if not FORGEJO_HOST or not FORGEJO_REPO:
    sys.exit("error: origin is not the Forgejo remote; set FORGEJO_HOST and FORGEJO_REPO")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "tafli/RealChord")
CI_IMAGE_FORGEJO = f"{FORGEJO_HOST}/{FORGEJO_REPO.split('/')[0]}/realchord-ci"
CI_IMAGE_GITHUB = f"ghcr.io/{GITHUB_REPO.split('/')[0]}/realchord-ci"

PR_LABEL = ("imported:pull-request", "ededed", "Pull request imported from the previous tracker")

# Anything that points to the Forgejo instance. Must not appear on GitHub.
FORBIDDEN = re.compile(re.escape(FORGEJO_HOST), re.IGNORECASE)

# Seconds between write requests (GitHub asks for at least one second between
# content-creating requests; secondary rate limit 80/min, 500/h).
WRITE_DELAY = float(os.environ.get("WRITE_DELAY", "1.2"))


# --------------------------------------------------------------------------- rules


def replacement_rules() -> list[tuple[str, str]]:
    """Regex rules (Python syntax), applied in order to git history and issue texts."""
    h = re.escape(FORGEJO_HOST)
    owner_repo = re.escape(FORGEJO_REPO)
    owner = re.escape(FORGEJO_REPO.split("/")[0])
    gh = GITHUB_REPO
    gh_owner = GITHUB_REPO.split("/")[0]
    return [
        (rf"ssh://git@{h}/{owner_repo}\.git", f"git@github.com:{gh}.git"),
        (rf"git@{h}:{owner_repo}\.git", f"git@github.com:{gh}.git"),
        (rf"https?://{h}/{owner_repo}/pulls/(\d+)", rf"https://github.com/{gh}/pull/\1"),
        (rf"https?://{h}/{owner_repo}/issues/(\d+)", rf"https://github.com/{gh}/issues/\1"),
        (rf"https?://{h}/{owner_repo}/src/(?:branch|commit)/", f"https://github.com/{gh}/blob/"),
        (rf"{re.escape(CI_IMAGE_FORGEJO)}", CI_IMAGE_GITHUB),
        (rf"docker login {h}", "docker login ghcr.io"),
        (rf"{h}/{owner_repo}", f"github.com/{gh}"),
        (rf"{h}/{owner}/", f"github.com/{gh_owner}/"),
        (rf"https?://{h}", "https://github.com"),
        (h, "github.com"),
    ]


def filter_repo_rules() -> str:
    """The rules in the `--replace-text` file format of git filter-repo."""
    lines = []
    for pattern, repl in replacement_rules():
        assert "==>" not in pattern + repl
        lines.append(f"regex:{pattern}==>{repl}")
    return "\n".join(lines) + "\n"


def load_commit_map() -> dict[str, str]:
    """Old -> new commit ids from the history rewrite (history.sh), if done."""
    path = EXPORT_DIR / "repo.git" / "filter-repo" / "commit-map"
    if not path.exists():
        return {}
    mapping = {}
    for line in path.read_text().splitlines()[1:]:
        old, new = line.split()
        if old != new and set(new) != {"0"}:
            mapping[old] = new
    return mapping


SHA = re.compile(r"\b[0-9a-f]{7,40}\b")
MENTION = re.compile(r"(?<![\w.`/])@([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))\b")


def _clean_prose(text: str) -> str:
    # Neutralize @mentions (GitHub would notify unrelated users with that login).
    # Mentions inside URLs and e-mail addresses are skipped by the lookbehind.
    text = MENTION.sub(lambda m: f"`@{m.group(1)}`", text)
    return text


def clean(text: str | None, commit_map: dict[str, str]) -> str:
    """Rewrite a Forgejo text for GitHub: links, commit ids, @mentions."""
    if not text:
        return ""
    for pattern, repl in replacement_rules():
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)
    if commit_map:
        def sha(m: re.Match) -> str:
            s = m.group(0)
            hits = [new for old, new in commit_map.items() if old.startswith(s)]
            return hits[0][: len(s)] if len(hits) == 1 else s
        text = SHA.sub(sha, text)
    # @mentions only outside code blocks and inline code.
    parts = re.split(r"(```.*?```|`[^`\n]*`)", text, flags=re.DOTALL)
    return "".join(p if i % 2 else _clean_prose(p) for i, p in enumerate(parts))


def check_clean(where: str, text: str) -> None:
    if FORBIDDEN.search(text):
        sys.exit(f"error: {where} still references {FORGEJO_HOST} after cleaning:\n{text}")


# ---------------------------------------------------------------------------- HTTP


def forgejo_token() -> str:
    if os.environ.get("FORGEJO_TOKEN"):
        return os.environ["FORGEJO_TOKEN"]
    keys = Path.home() / ".local/share/forgejo-cli/keys.json"
    try:
        return json.loads(keys.read_text())["hosts"][FORGEJO_HOST]["token"]
    except (OSError, KeyError, ValueError):
        sys.exit("error: set FORGEJO_TOKEN or log in with `fj -H %s auth login`" % FORGEJO_HOST)


def github_token() -> str:
    if os.environ.get("GITHUB_TOKEN"):
        return os.environ["GITHUB_TOKEN"]
    try:
        return subprocess.run(["gh", "auth", "token"], check=True, capture_output=True,
                              text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("error: set GITHUB_TOKEN or log in with `gh auth login`")


class Api:
    def __init__(self, base: str, auth: str, extra: dict[str, str] | None = None):
        self.base, self.auth, self.extra = base, auth, extra or {}
        self.last_write = 0.0

    def call(self, method: str, path: str, body: object | None = None) -> object:
        url = path if path.startswith("http") else self.base + path
        if method != "GET":
            wait = self.last_write + WRITE_DELAY - time.monotonic()
            if wait > 0:
                time.sleep(wait)
        for attempt in range(8):
            req = urllib.request.Request(url, method=method, headers={
                "Authorization": self.auth, "Accept": "application/json",
                "Content-Type": "application/json", "User-Agent": "realchord-migration",
                **self.extra})
            if body is not None:
                req.data = json.dumps(body).encode()
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    if method != "GET":
                        self.last_write = time.monotonic()
                    data = resp.read()
                    return json.loads(data) if data else None
            except urllib.error.HTTPError as e:
                detail = e.read().decode(errors="replace")
                limited = e.code == 429 or (e.code == 403 and "rate limit" in detail.lower())
                if limited:
                    retry = e.headers.get("Retry-After")
                    reset = e.headers.get("X-RateLimit-Reset")
                    delay = int(retry) if retry else (
                        max(5, int(reset) - int(time.time()) + 2) if reset else 60 * 2 ** attempt)
                    print(f"  rate limited, waiting {delay}s …", file=sys.stderr)
                    time.sleep(delay)
                    continue
                if e.code >= 500 and attempt < 3:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise SystemExit(f"error: {method} {url} -> {e.code}: {detail}") from None
        raise SystemExit(f"error: {method} {url} kept failing")

    def pages(self, path: str, per_page: int = 50) -> list:
        out, page = [], 1
        sep = "&" if "?" in path else "?"
        while True:
            batch = self.call("GET", f"{path}{sep}limit={per_page}&per_page={per_page}&page={page}")
            out.extend(batch)
            if len(batch) < per_page:
                return out
            page += 1


def forgejo() -> Api:
    return Api(f"https://{FORGEJO_HOST}/api/v1/repos/{FORGEJO_REPO}", f"token {forgejo_token()}")


def github() -> Api:
    return Api(f"https://api.github.com/repos/{GITHUB_REPO}", f"Bearer {github_token()}",
               {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})


# -------------------------------------------------------------------------- export


def cmd_export(_args) -> None:
    fj = forgejo()
    print(f"Exporting {FORGEJO_HOST}/{FORGEJO_REPO} …")
    repo = fj.call("GET", "")
    labels = fj.pages("/labels")
    milestones = fj.pages("/milestones?state=all")
    items = fj.pages("/issues?state=all")
    pulls = {p["number"]: p for p in fj.pages("/pulls?state=all")}
    for item in items:
        n = item["number"]
        item["comments_list"] = fj.pages(f"/issues/{n}/comments") if item["comments"] else []
        if item.get("pull_request"):
            item["pull"] = pulls.get(n) or fj.call("GET", f"/pulls/{n}")
    items.sort(key=lambda i: i["number"])
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    out = EXPORT_DIR / "forgejo.json"
    out.write_text(json.dumps({"repo": repo, "labels": labels, "milestones": milestones,
                               "items": items}, indent=1, ensure_ascii=False))
    n_pr = sum(1 for i in items if i.get("pull_request"))
    open_items = [i["number"] for i in items if i["state"] == "open"]
    print(f"  {len(labels)} labels, {len(milestones)} milestones, {len(items) - n_pr} issues, "
          f"{n_pr} pull requests, {sum(len(i['comments_list']) for i in items)} comments")
    print(f"  written to {out}")
    if open_items:
        print(f"  warning: still open on Forgejo: {open_items} (close them before the migration)")


def load_export() -> dict:
    path = EXPORT_DIR / "forgejo.json"
    if not path.exists():
        sys.exit(f"error: {path} missing, run `migrate.py export` first")
    return json.loads(path.read_text())


# -------------------------------------------------------------------------- mapping


def date(s: str | None) -> str:
    return s[:16].replace("T", " ") + " UTC" if s else "?"


def utc(s: str | None) -> str | None:
    # Forgejo returns local offsets (e.g. +01:00); normalise to UTC for the header.
    if not s:
        return None
    from datetime import datetime, timezone
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat()


def build_issue(item: dict, commit_map: dict[str, str]) -> dict:
    """The GitHub issue (title, body, labels, state) for one Forgejo item."""
    n = item["number"]
    user = item["user"]["login"]
    pr = item.get("pull")
    meta = [f"Originally opened by `{user}` on {date(utc(item['created_at']))}"]
    if pr:
        head_info = pr.get("head") or {}
        # After the branch is deleted, ref is refs/pull/N/head; label keeps the name.
        head = head_info.get("label") or head_info.get("ref", "?")
        base = (pr.get("base") or {}).get("ref", "?")
        meta.insert(0, f"Pull request `{head}` → `{base}` (imported as an issue)")
        if pr.get("merged"):
            sha = pr.get("merge_commit_sha") or ""
            sha = commit_map.get(sha, sha)
            by = (pr.get("merged_by") or {}).get("login")
            meta.append("merged" + (f" by `{by}`" if by else "")
                        + f" on {date(utc(pr.get('merged_at')))}" + (f" as {sha}" if sha else ""))
        elif item["state"] == "closed":
            meta.append(f"closed without merge on {date(utc(item.get('closed_at')))}")
    elif item["state"] == "closed":
        meta.append(f"closed on {date(utc(item.get('closed_at')))}")
    header = "> " + " · ".join(meta) + f"\n<!-- realchord-migration: {n} -->\n\n"
    body = header + clean(item.get("body"), commit_map)
    if len(body) > 65000:
        body = body[:65000] + "\n\n… (truncated during the migration)"
    labels = [lb["name"] for lb in item.get("labels") or []]
    if pr:
        labels.append(PR_LABEL[0])
    comments = []
    for c in item.get("comments_list", []):
        text = (f"> `{c['user']['login']}` commented on {date(utc(c['created_at']))}\n\n"
                + clean(c.get("body"), commit_map))
        comments.append(text[:65000])
    reason = None
    if item["state"] == "closed":
        reason = "not_planned" if pr and not pr.get("merged") else "completed"
    title = clean(item["title"], commit_map)
    for where, text in [("title", title), ("body", body), *[("comment", c) for c in comments]]:
        check_clean(f"#{n} {where}", text)
    return {"number": n, "title": title, "body": body, "labels": labels,
            "milestone": (item.get("milestone") or {}).get("title"), "comments": comments,
            "close": reason, "is_pr": bool(pr)}


def build_all(export: dict) -> list[dict]:
    commit_map = load_commit_map()
    by_number = {i["number"]: i for i in export["items"]}
    top = max(by_number, default=0)
    out = []
    for n in range(1, top + 1):
        if n in by_number:
            out.append(build_issue(by_number[n], commit_map))
        else:
            # Gap (deleted on Forgejo): a closed placeholder keeps the numbers aligned.
            out.append({"number": n, "title": "Placeholder (deleted before the migration)",
                        "body": f"<!-- realchord-migration: {n} -->\nThis number was not used.",
                        "labels": [], "milestone": None, "comments": [],
                        "close": "not_planned", "is_pr": False})
    return out


# -------------------------------------------------------------------------- import


def cmd_rules(_args) -> None:
    sys.stdout.write(filter_repo_rules())


def cmd_plan(_args) -> None:
    export = load_export()
    plan = build_all(export)
    commit_map = load_commit_map()
    print(f"Target: github.com/{GITHUB_REPO}")
    print(f"History rewrite: {'commit map with %d entries' % len(commit_map) if commit_map else 'NOT done yet (run history.sh first; commit ids in texts stay old)'}")
    print(f"Labels: {len(export['labels']) + 1}, milestones: {len(export['milestones'])}")
    for issue in plan:
        kind = "PR   " if issue["is_pr"] else "issue"
        state = issue["close"] or "open"
        print(f"  #{issue['number']:<4} {kind} {state:<11} {len(issue['comments'])}c  {issue['title'][:70]}")
    open_items = [i["number"] for i in plan if not i["close"]]
    print(f"{len(plan)} items, {sum(len(i['comments']) for i in plan)} comments, "
          f"~{len(plan) * 2 + sum(len(i['comments']) for i in plan)} write requests")
    if open_items:
        print(f"warning: open items {open_items} would be imported as open issues")
    print(f"OK: no text references {FORGEJO_HOST}.")


def github_max_number(gh: Api) -> int:
    latest = gh.call("GET", "/issues?state=all&sort=created&direction=desc&per_page=1")
    pulls = gh.call("GET", "/pulls?state=all&sort=created&direction=desc&per_page=1")
    return max([i["number"] for i in latest] + [p["number"] for p in pulls] + [0])


def cmd_import(args) -> None:
    export = load_export()
    plan = build_all(export)
    if not load_commit_map() and not args.allow_old_commit_ids:
        sys.exit("error: no commit map; run tool/github-migration/history.sh first "
                 "(or pass --allow-old-commit-ids)")
    gh = github()
    repo = gh.call("GET", "")
    if not repo.get("has_issues"):
        sys.exit("error: issues are disabled on the GitHub repository")
    state_path = EXPORT_DIR / "import-state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}

    def save() -> None:
        state_path.write_text(json.dumps(state, indent=1))

    # Labels (update the GitHub defaults with the same name) and milestones.
    existing = {lb["name"].lower(): lb for lb in gh.pages("/labels", 100)}
    wanted = [(lb["name"], lb["color"].lstrip("#"), lb.get("description") or "")
              for lb in export["labels"]] + [PR_LABEL]
    for name, color, desc in wanted:
        desc = clean(desc, {})[:100]
        if name.lower() in existing:
            cur = existing[name.lower()]
            if cur["color"] != color or (cur.get("description") or "") != desc:
                gh.call("PATCH", f"/labels/{urllib.request.quote(cur['name'], safe='')}",
                        {"new_name": name, "color": color, "description": desc})
        else:
            gh.call("POST", "/labels", {"name": name, "color": color, "description": desc})
            print(f"  label {name}")
    milestones = {m["title"]: m["number"] for m in gh.pages("/milestones?state=all", 100)}
    for m in export["milestones"]:
        if m["title"] not in milestones:
            created = gh.call("POST", "/milestones", {
                "title": m["title"], "description": clean(m.get("description"), {}),
                "state": "closed" if m["state"] == "closed" else "open",
                **({"due_on": m["due_on"]} if m.get("due_on") else {})})
            milestones[m["title"]] = created["number"]

    top = github_max_number(gh)
    for issue in plan:
        n = issue["number"]
        st = state.setdefault(str(n), {"created": False, "comments": 0, "closed": False})
        if not st["created"]:
            if n <= top:
                # Created in an earlier run that died before saving the state?
                existing_issue = gh.call("GET", f"/issues/{n}")
                marker = f"<!-- realchord-migration: {n} -->"
                if marker not in (existing_issue.get("body") or ""):
                    sys.exit(f"error: GitHub #{n} exists and was not created by this import; "
                             "the numbers cannot be aligned (the repository must be empty)")
                st["created"] = True
            else:
                if n != top + 1:
                    sys.exit(f"error: next GitHub number is {top + 1}, expected {n}")
                body = {"title": issue["title"], "body": issue["body"], "labels": issue["labels"]}
                if issue["milestone"]:
                    body["milestone"] = milestones[issue["milestone"]]
                created = gh.call("POST", "/issues", body)
                if created["number"] != n:
                    sys.exit(f"error: GitHub assigned #{created['number']} instead of #{n}; stop "
                             "and check the repository (something else created an issue or PR)")
                top = n
                st["created"] = True
            save()
            print(f"#{n} {issue['title'][:70]}")
        for i in range(st["comments"], len(issue["comments"])):
            gh.call("POST", f"/issues/{n}/comments", {"body": issue["comments"][i]})
            st["comments"] = i + 1
            save()
        if issue["close"] and not st["closed"]:
            gh.call("PATCH", f"/issues/{n}", {"state": "closed", "state_reason": issue["close"]})
            st["closed"] = True
            save()
    print(f"Imported {len(plan)} items into github.com/{GITHUB_REPO}.")


# ------------------------------------------------------------------ settings/verify


def cmd_settings(_args) -> None:
    gh = github()
    gh.call("PATCH", "", {
        "has_issues": True, "has_wiki": False, "has_projects": False, "has_discussions": False,
        "allow_squash_merge": True, "allow_merge_commit": False, "allow_rebase_merge": False,
        "allow_auto_merge": False, "delete_branch_on_merge": True,
        "squash_merge_commit_title": "PR_TITLE", "squash_merge_commit_message": "PR_BODY",
    })
    print(f"Settings applied to github.com/{GITHUB_REPO}: squash merge only (title = PR title), "
          "delete branch after merge, no wiki/projects/discussions.")


def cmd_verify(_args) -> None:
    plan = build_all(load_export())
    gh = github()
    issues = {i["number"]: i for i in gh.pages("/issues?state=all", 100)}
    problems = []
    for want in plan:
        got = issues.get(want["number"])
        if not got:
            problems.append(f"#{want['number']} missing")
            continue
        if "pull_request" in got:
            problems.append(f"#{want['number']} is a pull request on GitHub")
        if got["title"] != want["title"]:
            problems.append(f"#{want['number']} title differs: {got['title']!r}")
        if (got["state"] == "closed") != bool(want["close"]):
            problems.append(f"#{want['number']} state {got['state']}")
        if got["comments"] != len(want["comments"]):
            problems.append(f"#{want['number']} has {got['comments']} comments, "
                            f"expected {len(want['comments'])}")
    texts = [(f"#{i['number']}", (i["title"] or "") + (i["body"] or "")) for i in issues.values()]
    texts += [(c["html_url"], c["body"] or "") for c in gh.pages("/issues/comments", 100)]
    texts += [(f"label {lb['name']}", lb["name"] + (lb.get("description") or ""))
              for lb in gh.pages("/labels", 100)]
    problems += [f"{where} references {FORGEJO_HOST}" for where, t in texts if FORBIDDEN.search(t)]
    if problems:
        print("\n".join(problems))
        sys.exit(f"verify failed: {len(problems)} problem(s)")
    print(f"OK: {len(plan)} items match, no reference to {FORGEJO_HOST} on GitHub.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name in ("export", "rules", "plan", "settings", "verify"):
        sub.add_parser(name)
    imp = sub.add_parser("import")
    imp.add_argument("--allow-old-commit-ids", action="store_true",
                     help="import without a history rewrite (commit ids in texts stay unmapped)")
    args = parser.parse_args()
    globals()[f"cmd_{args.cmd}"](args)


if __name__ == "__main__":
    main()
