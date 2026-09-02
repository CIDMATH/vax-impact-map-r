#!/usr/bin/env python3
"""
Refresh the two CHC tracker CSVs from the Common Health Coalition
"State Vaccine Access Policy Tracker" web app.

Source (public, no sign-in):
  https://script.google.com/macros/s/AKfycbxpQ_nuXzoO9RcrPjc0GLdmhj7VVpuyyShe5YnC9Zdh29Z6m64w-_GApGp_CGOZHtxZ7g/exec

How the tracker serves its data
  The exec URL returns an Apps Script wrapper page. The tracker's own HTML is
  embedded in that wrapper as a JS-escaped string ("userHtml"). Inside that
  HTML a <script> declares `var DATA = {...}` carrying both tabs in full:
    dh / db  "State Infrastructure Database"  (headers / rows)
    ah / ac  "State Policy Actions"           (headers / rows)
    lu       the tracker's "Last updated" date, MM/DD/YYYY
  Row shape: {"s": state, "f": 1 for the first row of a state else 0,
              "c"/"sc": display flags, "mu" or "bu": source URL, "v": [cells]}
  Continuation rows (f = 0) have null in the state cell and a shorter v.
  No Google sign-in, API key or Sheets access is needed: one HTTP GET.

Outputs (same content in both places, matching the other data-raw scripts)
  data-raw/csv/chc_state_infrastructure_database.csv
  data-raw/csv/chc_state_policy_actions.csv
  data/csv/chc_state_infrastructure_database.csv
  data/csv/chc_state_policy_actions.csv

Usage
  pip install requests
  python data-raw/pull_chc_tracker.py               # fetch, diff vs committed, write
  python data-raw/pull_chc_tracker.py --dry-run     # fetch and diff only
  python data-raw/pull_chc_tracker.py --html page.html   # parse a saved copy of the page
  python data-raw/pull_chc_tracker.py --json data.json   # build from a saved DATA object
  python data-raw/pull_chc_tracker.py --dump-json out.json  # also save the DATA object

Failure modes
  The script stops (exit 1, nothing written) if the page has no userHtml
  marker, no `var DATA`, a different header list than the one it expects, or
  a Google sign-in page instead of the tracker. Those are the signals that CHC
  changed the page or restricted access; re-check the tracker in a browser.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
from pathlib import Path

TRACKER_URL = (
    "https://script.google.com/macros/s/"
    "AKfycbxpQ_nuXzoO9RcrPjc0GLdmhj7VVpuyyShe5YnC9Zdh29Z6m64w-_GApGp_CGOZHtxZ7g/exec"
)

# Header lists the tracker served on 2026-09-02. The script refuses to run if
# these change, because the column mapping below is positional.
EXPECTED_DH = [
    "State", "Reduced Reliance on ACIP?", "Mode of Action",
    "Alternative Bodies Referenced", "Vaccines Impacted", "Action Expiration",
    "Cost-Sharing Prohibited  for Mandated Vaccines?",
    "Basis of Vaccine  Coverage Mandate", "Pharmacist Vaccination Authority",
    "Minimum Age for Pharmacist-Administered Vaccines", "Exemptions Allowed",
    "Governor's Party", "Legislative Control Party", "Convene", "Adjourn",
]
EXPECTED_AH = [
    "State", "Bill/Act/Order", "Type of Action", "Mode of Action",
    "Vaccines Impacted", "Enacted (Y/N)", "Date Enacted", "Action Expiration",
    "Summary", "Notes",
]

INFRA_COLUMNS = [
    "state", "mode_of_action", "reduced_reliance_acip", "alternative_bodies",
    "vaccines_impacted", "action_expiration", "source_url",
    "cost_sharing_prohibited", "basis_of_coverage_mandate",
    "pharmacist_vax_authority", "min_age_pharmacist_vax", "exemptions_allowed",
    "governor_party", "legislative_control_party", "session_convene",
    "session_adjourn", "has_source_link", "source_year", "source_tracker_url",
]
POLICY_COLUMNS = [
    "state", "bill_act_order", "bill_url", "type_of_action", "mode_of_action",
    "vaccines_impacted", "enacted", "date_enacted", "action_expiration",
    "summary", "notes", "enacted_bool", "last_updated", "source_year",
    "source_tracker_url",
]

INFRA_NAME = "chc_state_infrastructure_database.csv"
POLICY_NAME = "chc_state_policy_actions.csv"


# --------------------------------------------------------------------------
# 1. Fetch and unwrap the page
# --------------------------------------------------------------------------

def fetch_page(url: str) -> str:
    try:
        import requests
    except ImportError:
        sys.exit("requests is not installed: pip install requests")
    r = requests.get(url, allow_redirects=True, timeout=60,
                     headers={"User-Agent": "vax-impact-map-r/pull_chc_tracker"})
    r.raise_for_status()
    if "accounts.google.com" in r.url or "ServiceLogin" in r.url:
        sys.exit("The tracker redirected to a Google sign-in page; it is no longer public.")
    return r.text


_ESC = re.compile(r"\\(x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|.)", re.S)
_SIMPLE = {"n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f", "v": "\v", "0": "\0"}


def js_unescape(s: str) -> str:
    """Decode one layer of JavaScript string escapes (\\xNN, \\uNNNN, \\n, \\", \\/, \\\\ ...)."""
    def sub(m: re.Match) -> str:
        e = m.group(1)
        if e[0] == "x" and len(e) == 3:
            return chr(int(e[1:], 16))
        if e[0] == "u" and len(e) == 5:
            return chr(int(e[1:], 16))
        return _SIMPLE.get(e, e)  # \" \\ \/ \' and anything else -> the char itself
    return _ESC.sub(sub, s)


def extract_user_html(wrapper: str) -> str:
    """Pull the tracker's HTML out of the Apps Script wrapper.

    The wrapper carries `\\x22userHtml\\x22:\\x22<...>\\x22` where <...> is the
    tracker HTML, JSON-escaped (layer 2) and then JS-escaped with \\xNN (layer 1).
    The closing \\x22 is the first one preceded by an even number of `\\\\` pairs;
    an odd number means it is a JSON-escaped quote inside the HTML.
    """
    marker = "\\x22userHtml\\x22:\\x22"
    start = wrapper.find(marker)
    if start < 0:
        sys.exit("Could not find the userHtml marker in the page; the tracker wrapper changed.")
    i = start + len(marker)
    j, pairs, n = i, 0, len(wrapper)
    while j < n:
        if wrapper[j] == "\\":
            if wrapper[j + 1:j + 4] == "x22":
                if pairs % 2 == 0:
                    break
                pairs = 0
                j += 4
                continue
            if wrapper[j + 1:j + 2] == "\\":
                pairs += 1
                j += 2
                continue
            pairs = 0
            j += 2
            continue
        pairs = 0
        j += 1
    else:
        sys.exit("userHtml string never terminated; the tracker wrapper changed.")
    layer1 = js_unescape(wrapper[i:j])   # -> JSON-escaped HTML
    return js_unescape(layer1)           # -> HTML


def extract_data(user_html: str) -> dict:
    """Brace-match `var DATA = {...}` and parse it as JSON."""
    k = user_html.find("var DATA = {")
    if k < 0:
        sys.exit("No `var DATA` block in the tracker HTML; the page structure changed.")
    p = k + len("var DATA = ")
    depth, in_str, esc = 0, False, False
    for q in range(p, len(user_html)):
        ch = user_html[q]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return json.loads(user_html[p:q + 1])
    sys.exit("Unbalanced braces in the DATA block.")


# --------------------------------------------------------------------------
# 2. Map DATA to the two CSV schemas
# --------------------------------------------------------------------------

def norm_state(s: str) -> str:
    s = (s or "").strip()
    return "District of Columbia" if s.startswith("District of Columbia") else s


def cell(v: list, i: int) -> str:
    """v[i] as text; continuation rows have short v and null state cells.
    Line breaks inside a sheet cell become " / " so no CSV cell spans lines
    (the committed files already use this for the Florida and Virginia
    session dates)."""
    if i < len(v) and v[i] is not None:
        return re.sub(r"\s*\r?\n\s*", " / ", str(v[i]))
    return ""


_MDY = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")


def short_date(s: str) -> str:
    """09/18/2025 -> 9/18/2025 (the policy file stores dates without leading zeros).
    Anything that is not a full M/D/YYYY date ("Pending", "Dead", "") is left alone."""
    m = _MDY.match(s.strip())
    if not m:
        return s
    return f"{int(m.group(1))}/{int(m.group(2))}/{m.group(3)}"


def build_tables(data: dict) -> tuple[list[dict], list[dict], str]:
    if data.get("dh") != EXPECTED_DH:
        sys.exit("Infrastructure headers changed:\n  got      %r\n  expected %r" % (data.get("dh"), EXPECTED_DH))
    if data.get("ah") != EXPECTED_AH:
        sys.exit("Policy headers changed:\n  got      %r\n  expected %r" % (data.get("ah"), EXPECTED_AH))
    lu = str(data.get("lu", "")).strip()
    if not _MDY.match(lu):
        sys.exit(f"Unexpected last-updated value {lu!r}")
    last_updated = short_date(lu)
    source_year = lu.split("/")[-1]

    if len(data.get("db", [])) < 51 or len(data.get("ac", [])) < 51:
        sys.exit("Suspiciously few rows (db %d, ac %d); the page may have been truncated."
                 % (len(data.get("db", [])), len(data.get("ac", []))))

    infra = []
    for row in data["db"]:
        v = row.get("v", [])
        url = (row.get("mu") or "").strip()
        infra.append({
            "state": norm_state(row.get("s")),
            "mode_of_action": cell(v, 2),
            "reduced_reliance_acip": cell(v, 1),
            "alternative_bodies": cell(v, 3),
            "vaccines_impacted": cell(v, 4),
            "action_expiration": cell(v, 5),
            "source_url": url,
            "cost_sharing_prohibited": cell(v, 6),
            "basis_of_coverage_mandate": cell(v, 7),
            "pharmacist_vax_authority": cell(v, 8),
            "min_age_pharmacist_vax": cell(v, 9),
            "exemptions_allowed": cell(v, 10),
            "governor_party": cell(v, 11),
            "legislative_control_party": cell(v, 12),
            "session_convene": cell(v, 13),
            "session_adjourn": cell(v, 14),
            "has_source_link": "TRUE" if url else "FALSE",
            "source_year": source_year,
            "source_tracker_url": TRACKER_URL,
        })

    policy = []
    for row in data["ac"]:
        v = row.get("v", [])
        enacted = cell(v, 5).strip()
        policy.append({
            "state": norm_state(row.get("s")),
            "bill_act_order": cell(v, 1),
            "bill_url": (row.get("bu") or "").strip(),
            "type_of_action": cell(v, 2),
            "mode_of_action": cell(v, 3),
            "vaccines_impacted": cell(v, 4),
            "enacted": enacted,
            "date_enacted": short_date(cell(v, 6)),
            "action_expiration": short_date(cell(v, 7)),
            "summary": cell(v, 8),
            "notes": cell(v, 9),
            "enacted_bool": "TRUE" if enacted.upper() == "Y" else "FALSE",
            "last_updated": last_updated,
            "source_year": source_year,
            "source_tracker_url": TRACKER_URL,
        })
    return infra, policy, lu


# --------------------------------------------------------------------------
# 3. Diff against the committed files and write
# --------------------------------------------------------------------------

def read_csv(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def row_key(r: dict, fields: tuple[str, ...]) -> tuple:
    return tuple((r.get(f) or "").strip() for f in fields)


def _show_change(ov: str, nv: str, width: int = 70) -> str:
    """Show the two values from the first character where they differ."""
    i = 0
    while i < min(len(ov), len(nv)) and ov[i] == nv[i]:
        i += 1
    start = max(0, i - 15)
    pre = "..." if start else ""
    return f"{pre}{ov[start:start + width]!r} -> {pre}{nv[start:start + width]!r}"


def diff_rows(old: list[dict], new: list[dict], key_fields: tuple[str, ...],
              ignore: tuple[str, ...] = ()) -> list[str]:
    """Match rows on key_fields, report added / removed / changed. Order-insensitive."""
    lines = []
    old_by: dict[tuple, list[dict]] = {}
    for r in old:
        old_by.setdefault(row_key(r, key_fields), []).append(r)
    new_by: dict[tuple, list[dict]] = {}
    for r in new:
        new_by.setdefault(row_key(r, key_fields), []).append(r)

    def label(k: tuple) -> str:
        return " | ".join(x for x in k if x)[:110]

    for k in new_by:
        if k not in old_by:
            for _ in new_by[k]:
                lines.append(f"  + added    {label(k)}")
    for k in old_by:
        if k not in new_by:
            for _ in old_by[k]:
                lines.append(f"  - removed  {label(k)}")
    for k in new_by:
        if k in old_by:
            for o, n in zip(old_by[k], new_by[k]):
                changed = []
                for f in n:
                    if f in ignore:
                        continue
                    ov, nv = (o.get(f) or "").strip(), (n.get(f) or "").strip()
                    if ov != nv:
                        changed.append(f"      {f}: {_show_change(ov, nv)}")
                if changed:
                    lines.append(f"  ~ changed  {label(k)}\n" + "\n".join(changed))
            if len(old_by[k]) != len(new_by[k]):
                lines.append(f"  ~ count    {label(k)}: {len(old_by[k])} -> {len(new_by[k])} rows")
    return lines


def write_csv(path: Path, rows: list[dict], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # newline="" + the csv module's default line terminator gives CRLF, the same
    # as the other data-raw scripts; git normalises it on commit.
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=columns, extrasaction="raise")
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent,
                    help="repo root (default: parent of data-raw/)")
    ap.add_argument("--url", default=TRACKER_URL)
    ap.add_argument("--html", type=Path, help="parse a saved copy of the exec page instead of fetching")
    ap.add_argument("--json", type=Path, help="build from a saved DATA object instead of fetching")
    ap.add_argument("--dump-json", type=Path, help="save the extracted DATA object here")
    ap.add_argument("--save-page", type=Path, help="save the fetched page here (useful if parsing fails)")
    ap.add_argument("--dry-run", action="store_true", help="fetch and diff, write nothing")
    args = ap.parse_args()

    if args.json:
        data = json.loads(args.json.read_text(encoding="utf-8"))
        print(f"DATA from {args.json}")
    else:
        if args.html:
            wrapper = args.html.read_text(encoding="utf-8")
            print(f"page from {args.html} ({len(wrapper):,} chars)")
        else:
            wrapper = fetch_page(args.url)
            print(f"fetched {args.url} ({len(wrapper):,} chars)")
        if args.save_page:
            args.save_page.write_text(wrapper, encoding="utf-8")
            print(f"page saved to {args.save_page}")
        data = extract_data(extract_user_html(wrapper))

    if args.dump_json:
        args.dump_json.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"DATA saved to {args.dump_json}")

    infra, policy, lu = build_tables(data)
    states_i = sorted({r["state"] for r in infra})
    states_p = sorted({r["state"] for r in policy})
    print(f"tracker last updated {lu}")
    print(f"infrastructure: {len(infra)} rows, {len(states_i)} jurisdictions")
    print(f"policy actions: {len(policy)} rows, {len(states_p)} jurisdictions")
    if len(states_i) != 51:
        print(f"  NOTE: the infrastructure tab should cover 51 jurisdictions, got {len(states_i)}")
    missing = [s for s in states_p if s not in states_i]
    if missing:
        print(f"  NOTE: states in the policy tab but not the infrastructure tab: {missing}")

    targets = {
        "infrastructure": (infra, INFRA_COLUMNS, INFRA_NAME,
                           ("state", "mode_of_action", "vaccines_impacted", "source_url")),
        "policy actions": (policy, POLICY_COLUMNS, POLICY_NAME,
                           ("state", "bill_act_order", "mode_of_action", "bill_url")),
    }
    for name, (rows, cols, fname, key) in targets.items():
        committed = args.repo / "data" / "csv" / fname
        old = read_csv(committed)
        print(f"\n{name}: vs {committed.relative_to(args.repo) if committed.exists() else '(no committed file)'}")
        if old:
            lines = diff_rows(old, rows, key, ignore=("last_updated",))
            if lines:
                print("\n".join(lines))
            else:
                print("  no row-level changes")
            old_lu = {r.get("last_updated") for r in old} - {None, ""}
            if old_lu:
                print(f"  last_updated {sorted(old_lu)[0]} -> {short_date(lu)}")

    if args.dry_run:
        print("\n--dry-run: nothing written")
        return 0

    for name, (rows, cols, fname, key) in targets.items():
        for sub in ("data-raw/csv", "data/csv"):
            out = args.repo / sub / fname
            write_csv(out, rows, cols)
            print(f"wrote {out.relative_to(args.repo)} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
