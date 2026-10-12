#!/usr/bin/env python3
"""Track Apple School Manager and Apple Business API releases against what asbmutil implements.

docs/apple-api/coverage.json is the record: every changelog release Apple has published, every
documented endpoint with the platforms that serve it and our implementation status, and the
values of the enums we depend on (activity types, audit event types, statuses).

    scripts/apple-api-watch.py check     # compare Apple's live docs to the record; exit 3 on drift
    scripts/apple-api-watch.py update    # fold new releases, endpoints and enum values into the record
    scripts/apple-api-watch.py render    # regenerate docs/apple-api/COVERAGE.md from the record

New endpoints land with status "todo". Set status to "done" (with "where" naming the client
method and CLI command), "todo", or "skip" (with a "note" saying why), then render.
"""

import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

DOCS = "https://developer.apple.com/tutorials/data/documentation/"
PRODUCTS = {"school": "appleschoolmanagerapi", "business": "applebusinessapi"}
CHANGELOG = "apple-school-and-business-manager-api/apple-school-manager-and-apple-business-api-changelog"
NON_ENDPOINT_SECTIONS = {
    "Objects and Data Types",
    "Type Aliases",
    "Dictionaries",
    "Authentication",
}
ROOT = Path(__file__).resolve().parent.parent
RECORD = ROOT / "docs/apple-api/coverage.json"
COVERAGE_MD = ROOT / "docs/apple-api/COVERAGE.md"


def fetch(path):
    req = urllib.request.Request(
        DOCS + path + ".json", headers={"User-Agent": "asbmutil-apple-api-watch"}
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def text(node):
    if isinstance(node, list):
        return "".join(text(n) for n in node)
    if not isinstance(node, dict):
        return ""
    if node.get("type") == "text":
        return node["text"]
    if node.get("type") == "codeVoice":
        return node["code"]
    return "".join(
        text(node[k]) for k in ("inlineContent", "content", "items") if k in node
    )


def changelog_releases():
    """Release headings, newest first, e.g. '2.6 (Apple Business) - 2026/9/24'."""
    doc = fetch(CHANGELOG)
    out = []
    for section in doc["primaryContentSections"]:
        for block in section.get("content", []):
            if block.get("type") == "heading" and block.get("level", 2) <= 3:
                title = block.get("text", "").strip()
                if title and title[0].isdigit():
                    out.append(title)
    return out


def live_snapshot():
    endpoints, enums, pages = {}, {}, []
    for platform, product in PRODUCTS.items():
        index = fetch(product)
        for section in index["topicSections"]:
            for ident in section["identifiers"]:
                slug = product + "/" + ident.split("/")[-1].lower()
                if section["title"] == "Type Aliases":
                    pages.append(("enum", platform, slug))
                elif section["title"] not in NON_ENDPOINT_SECTIONS:
                    pages.append(("endpoint", platform, slug))

    with ThreadPoolExecutor(max_workers=6) as pool:
        docs = list(pool.map(lambda p: fetch(p[2]), pages))

    for (kind, platform, slug), doc in zip(pages, docs):
        sections = doc.get("primaryContentSections", [])
        if kind == "endpoint":
            rest = next((s for s in sections if s.get("kind") == "restEndpoint"), None)
            if not rest:
                continue
            raw = "".join(t["text"] for t in rest["tokens"])
            method, url = raw.split(" ", 1)
            path = "/" + url.split("/", 3)[3]
            key = f"{method} {path}"
            entry = endpoints.setdefault(
                key, {"title": doc["metadata"]["title"], "platforms": []}
            )
            entry["platforms"].append(platform)
        else:
            values = next(
                (s for s in sections if s.get("kind") == "possibleValues"), None
            )
            if values:
                name = doc["metadata"]["title"]
                merged = enums.setdefault(name, [])
                merged += [
                    v["name"] for v in values["values"] if v["name"] not in merged
                ]

    return {"changelog": changelog_releases(), "endpoints": endpoints, "enums": enums}


def load_record():
    if RECORD.exists():
        return json.loads(RECORD.read_text())
    return {"changelog": [], "endpoints": {}, "enums": {}}


def diff(record, live):
    report = []
    new_releases = [r for r in live["changelog"] if r not in record["changelog"]]
    if new_releases:
        report.append("New changelog releases:")
        report += [f"  + {r}" for r in new_releases]

    for key, entry in sorted(live["endpoints"].items()):
        known = record["endpoints"].get(key)
        if not known:
            report.append(
                f"New endpoint: {key} — {entry['title']} ({', '.join(entry['platforms'])})"
            )
        elif sorted(known["platforms"]) != sorted(entry["platforms"]):
            report.append(
                f"Platforms changed: {key} {known['platforms']} → {entry['platforms']}"
            )
    for key in sorted(set(record["endpoints"]) - set(live["endpoints"])):
        report.append(f"Endpoint no longer documented: {key}")

    for name, values in sorted(live["enums"].items()):
        known = record["enums"].get(name)
        if known is None:
            report.append(f"New enum: {name} = {', '.join(values)}")
            continue
        added = [v for v in values if v not in known]
        removed = [v for v in known if v not in values]
        if added:
            report.append(f"{name}: new values {', '.join(added)}")
        if removed:
            report.append(f"{name}: values removed {', '.join(removed)}")
    return report


def merge(record, live):
    record["changelog"] = live["changelog"] + [
        r for r in record["changelog"] if r not in live["changelog"]
    ]
    for key, entry in live["endpoints"].items():
        known = record["endpoints"].setdefault(key, {"status": "todo"})
        known["title"] = entry["title"]
        known["platforms"] = sorted(entry["platforms"])
    record["enums"] = {k: live["enums"][k] for k in sorted(live["enums"])}
    record["endpoints"] = dict(
        sorted(
            record["endpoints"].items(), key=lambda kv: (kv[0].split(" ", 1)[1], kv[0])
        )
    )
    return record


def render(record):
    marks = {"done": "Done", "todo": "To do", "skip": "Skipped"}
    lines = [
        "# Apple API coverage",
        "",
        "Generated from `docs/apple-api/coverage.json` by `scripts/apple-api-watch.py render`; edit the JSON, not this file.",
        "",
        f"Latest Apple release on record: **{record['changelog'][0] if record['changelog'] else 'none'}**.",
        "",
    ]
    counts = {
        s: sum(1 for e in record["endpoints"].values() if e.get("status") == s)
        for s in marks
    }
    lines += [", ".join(f"{marks[s]}: {n}" for s, n in counts.items()), ""]
    lines += [
        "| Endpoint | Apple title | Platforms | Status | Where / note |",
        "|---|---|---|---|---|",
    ]
    for key, e in record["endpoints"].items():
        platforms = " + ".join("ASM" if p == "school" else "AB" for p in e["platforms"])
        where = e.get("where") or e.get("note") or ""
        lines.append(
            f"| `{key}` | {e['title']} | {platforms} | {marks.get(e.get('status'), e.get('status'))} | {where} |"
        )
    lines += ["", "## Releases on record", ""]
    lines += [f"- {r}" for r in record["changelog"]]
    lines += ["", "## Enums on record", ""]
    for name, values in record["enums"].items():
        lines.append(f"- **{name}**: {', '.join(f'`{v}`' for v in values)}")
    return "\n".join(lines) + "\n"


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    record = load_record()
    if cmd == "render":
        COVERAGE_MD.write_text(render(record))
        return 0
    live = live_snapshot()
    report = diff(record, live)
    if cmd == "check":
        print(
            "\n".join(report)
            if report
            else "No changes: the record matches Apple's published docs."
        )
        todo = [k for k, e in record["endpoints"].items() if e.get("status") == "todo"]
        if todo:
            print(
                f"\n{len(todo)} documented endpoint(s) still to do — see docs/apple-api/COVERAGE.md."
            )
        return 3 if report else 0
    if cmd == "update":
        RECORD.parent.mkdir(parents=True, exist_ok=True)
        RECORD.write_text(json.dumps(merge(record, live), indent=2) + "\n")
        COVERAGE_MD.write_text(render(record))
        print("\n".join(report) if report else "No changes.")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
