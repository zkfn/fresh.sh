#!/usr/bin/env python3
"""Durable ledger for long-horizon refactoring campaigns.

State lives in .campaign/ledger.json. Every mutation is written immediately
and atomically, because the session holding it can end at any moment.
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

DIR = ".campaign"
PATH = os.path.join(DIR, "ledger.json")
HOT = os.path.join(DIR, "hot.json")
HOT_TTL = 1800          # refresh the open-PR file set every 30 min


def hot_files(refresh=False):
    """Files touched by currently-open PRs. Editing these in a new unit means
    a merge conflict against work already waiting on a human, so units that
    intersect this set are held back rather than started."""
    if not refresh and os.path.exists(HOT):
        with open(HOT) as f:
            c = json.load(f)
        if time.time() - c["at"] < HOT_TTL:
            return set(c["files"]), c["prs"], True
    try:
        out = subprocess.run(
            ["gh", "pr", "list", "--state", "open", "--json", "number,files,title"],
            capture_output=True, text=True, timeout=45)
        if out.returncode:
            return set(), [], False
        prs = json.loads(out.stdout)
        files, meta = set(), []
        for pr in prs:
            fs = [f["path"] for f in pr.get("files", [])]
            files.update(fs)
            meta.append({"number": pr["number"], "title": pr["title"], "files": fs})
        os.makedirs(DIR, exist_ok=True)
        with open(HOT, "w") as f:
            json.dump({"at": time.time(), "files": sorted(files), "prs": meta}, f, indent=2)
        return files, meta, False
    except Exception:
        return set(), [], False


def collides(unit, hot):
    return sorted(set(unit.get("files", [])) & hot)

# Complexity 1-5 -> effort multiplier. Superlinear: hard units are much worse
# than their line count suggests, which is exactly what naive LOC estimates miss.
COMPLEXITY_MULT = {1: 0.6, 2: 0.8, 3: 1.0, 4: 1.6, 5: 2.5}

SEED_TOKENS_PER_LOC = 120.0   # prior, used until real data exists
MIN_CALIB_LOC = 25            # smaller units are all fixed overhead, don't calibrate on them
SAFETY = 1.35                 # require this much headroom over the estimate


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def load():
    if not os.path.exists(PATH):
        sys.exit("No campaign here. Run: ledger.py init")
    with open(PATH) as f:
        return json.load(f)


def save(d):
    d["updated"] = now()
    tmp = PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent=2)
    os.replace(tmp, PATH)          # atomic; a crash mid-write can't corrupt it


def tokens_per_loc(d):
    """Rolling average over completed units. Recency-weighted: later units
    reflect the current state of the codebase and your current approach."""
    # Units below MIN_CALIB_LOC are excluded: their cost is dominated by fixed
    # per-unit overhead (survey, plan, PR) rather than by line count, so they
    # skew tokens-per-loc badly upward.
    samples = [(u["loc"], u["actual_tokens"], u.get("complexity", 3))
               for u in d["units"].values()
               if u.get("actual_tokens") and u.get("loc", 0) >= MIN_CALIB_LOC]
    if not samples:
        return SEED_TOKENS_PER_LOC, 0
    weights, total = [], 0.0
    for i, (loc, tok, cx) in enumerate(samples):
        w = 1.5 ** i                                   # recent units weigh more
        normalized = tok / (loc * COMPLEXITY_MULT.get(cx, 1.0))
        weights.append(w)
        total += w * normalized
    return total / sum(weights), len(samples)


def estimate(d, unit):
    tpl, _ = tokens_per_loc(d)
    return int(unit["loc"] * tpl * COMPLEXITY_MULT.get(unit.get("complexity", 3), 1.0))


def ready(d, unit):
    """Dependencies must be merged - not merely PR'd. An unmerged dependency
    can still change during review."""
    for dep in unit.get("depends_on", []):
        if d["units"].get(dep, {}).get("status") != "merged":
            return False
    return True


# --------------------------------------------------------------- commands

def cmd_init(a):
    if a.repo:
        os.chdir(a.repo)
    os.makedirs(DIR, exist_ok=True)
    if os.path.exists(PATH):
        sys.exit("Ledger already exists.")
    save({"created": now(), "units": {}, "issues": [], "findings": [],
          "checkpoints": [], "sessions": 0})
    print(f"Created {PATH}")


def cmd_scan(a):
    d = load()
    added = 0
    for p in sorted(glob.glob(a.pattern, recursive=True)):
        uid = os.path.basename(p).split(".")[0]
        if uid in d["units"]:
            continue
        with open(p, errors="ignore") as f:
            loc = sum(1 for ln in f if ln.strip() and not ln.strip().startswith("//"))
        d["units"][uid] = {"files": [p], "loc": loc, "complexity": 3,
                           "status": "pending", "depends_on": [],
                           "actual_tokens": None, "pr": None, "added": now()}
        added += 1
        print(f"  + {uid:<28} {loc:>5} loc")
    save(d)
    print(f"\nAdded {added} units. Set complexity where it isn't 3:")
    print("  ledger.py add <id> --complexity 5   (updates existing)")


def cmd_add(a):
    d = load()
    u = d["units"].get(a.id, {"status": "pending", "depends_on": [],
                              "actual_tokens": None, "pr": None, "added": now()})
    if a.files:
        u["files"] = sorted(glob.glob(a.files, recursive=True)) or [a.files]
    if a.loc is not None:
        u["loc"] = a.loc
    if a.complexity is not None:
        u["complexity"] = a.complexity
    u.setdefault("loc", 100)
    u.setdefault("complexity", 3)
    u.setdefault("files", [])
    if a.depends_on:
        u["depends_on"] = a.depends_on
    d["units"][a.id] = u
    save(d)
    print(f"{a.id}: loc={u['loc']} complexity={u['complexity']} "
          f"est={estimate(d, u):,} tokens")


def cmd_status(a):
    d = load()
    d["sessions"] += 1
    save(d)
    by = {}
    for uid, u in d["units"].items():
        by.setdefault(u["status"], []).append(uid)
    tpl, n = tokens_per_loc(d)

    print(f"\n=== campaign — session {d['sessions']} ===")
    for st in ("merged", "pr-open", "active", "blocked", "pending", "skipped"):
        if by.get(st):
            print(f"  {st:<9} {len(by[st]):>3}  {', '.join(sorted(by[st])[:6])}"
                  + (" …" if len(by[st]) > 6 else ""))

    total = len(d["units"])
    done = len(by.get("merged", []))
    if total:
        print(f"\n  progress  {done}/{total} merged ({100*done//total}%)")

    remaining = [u for u in d["units"].values() if u["status"] == "pending"]
    if remaining:
        print(f"  est. remaining  ~{sum(estimate(d, u) for u in remaining):,} tokens")
    src = f"calibrated on {n} unit(s)" if n else "SEED PRIOR — not yet calibrated"
    print(f"  tokens/loc  {tpl:.0f}  ({src})")

    if by.get("pr-open"):
        print("\n  waiting on review:")
        for uid in sorted(by["pr-open"]):
            print(f"    {uid}  {d['units'][uid].get('pr') or '(no url)'}")
        print("  → run: ledger.py sync")

    open_issues = [i for i in d["issues"] if i.get("deferred")]
    print(f"\n  issues logged {len(d['issues'])}  ({len(open_issues)} deferred)")

    if d["findings"]:
        print("\n  findings that affect remaining work:")
        for f in d["findings"][-8:]:
            print(f"    · {f['text']}")

    if d["checkpoints"]:
        c = d["checkpoints"][-1]
        print(f"\n  last handoff ({c['at']}):\n    {c['note']}")
    print()


def cmd_next(a):
    d = load()
    active = [u for u in d["units"].values() if u["status"] == "active"]
    if active:
        sys.exit("A unit is already active. Finish or release it first.")

    hot, prmeta, cached = hot_files(refresh=a.refresh_prs)
    if hot:
        print(f"({len(hot)} file(s) locked by {len(prmeta)} open PR"
              f"{'s' if len(prmeta) != 1 else ''}{', cached' if cached else ''})")

    cands, hotblocked = [], []
    for uid, u in d["units"].items():
        if u["status"] != "pending" or not ready(d, u):
            continue
        hit = collides(u, hot)
        if hit:
            hotblocked.append((uid, hit))
        else:
            cands.append((uid, u))

    if hotblocked:
        print("held back — files are in open PRs:")
        for uid, hit in hotblocked:
            print(f"  {uid}: {', '.join(hit[:3])}{' …' if len(hit) > 3 else ''}")

    if not cands:
        blocked = [uid for uid, u in d["units"].items()
                   if u["status"] == "pending" and not ready(d, u)]
        if hotblocked:
            print(f"\n{len(hotblocked)} unit(s) ready but locked by open PRs.")
            print("Merge or close those PRs, or run: ledger.py next --refresh-prs")
            return
        pr = [uid for uid, u in d["units"].items() if u["status"] == "pr-open"]
        if pr:
            print(f"Nothing ready. {len(pr)} unit(s) waiting on review: "
                  f"{', '.join(sorted(pr))}\nRun sync, or work outside the campaign.")
        elif blocked:
            print(f"All remaining units blocked by dependencies: {', '.join(blocked)}")
        else:
            print("Campaign complete. Run: ledger.py report")
        return

    # cheapest-first: more units finished per session, faster calibration,
    # and a session that dies late costs less.
    cands.sort(key=lambda kv: estimate(d, kv[1]))
    uid, u = cands[0]
    est = estimate(d, u)

    print(f"next: {uid}  ({u['loc']} loc, complexity {u['complexity']}, "
          f"est ~{est:,} tokens)")
    print(f"      files: {', '.join(u.get('files') or ['(none declared)'])}")
    if not u.get("files"):
        print("      ⚠ no files declared — this unit BYPASSES the PR collision")
        print("        guard. Set them: ledger.py add %s --files '<glob>'" % uid)

    if a.remaining_tokens is not None:
        need = int(est * SAFETY)
        print(f"      need ~{need:,} with safety margin, have {a.remaining_tokens:,}")
        if a.remaining_tokens < need:
            print("\n  ⚠ NOT ENOUGH CONTEXT. Do not start this unit.")
            print("    Half-finished units cost more to recover than they save.")
            print("    Run: ledger.py checkpoint --note '...'")
            return
    print(f"\n  ledger.py start {uid}")


def cmd_start(a):
    d = load()
    u = d["units"][a.id]
    u["status"] = "active"
    u["started"] = now()
    save(d)
    print(f"{a.id} active. Read references/unit-workflow.md for the inner loop.")


def cmd_issue(a):
    d = load()
    d["issues"].append({"unit": a.unit, "severity": a.severity, "text": a.text,
                        "deferred": a.deferred, "at": now()})
    save(d)
    print(f"logged [{a.severity}]{' DEFERRED' if a.deferred else ''}: {a.text}")
    if a.deferred:
        print("  → if this is real work, make it a unit: ledger.py add <id> ...")


def cmd_finding(a):
    d = load()
    d["findings"].append({"text": a.text, "at": now()})
    save(d)
    print(f"finding recorded — will surface at every future session start")


def cmd_finish(a):
    d = load()
    u = d["units"][a.id]
    est = estimate(d, u)          # BEFORE recording actuals, or drift is always 0%
    u["actual_tokens"] = a.tokens
    u["pr"] = a.pr
    u["status"] = "pr-open" if a.pr else "pending"
    u["finished"] = now()
    save(d)
    drift = (a.tokens - est) / est * 100 if est else 0
    print(f"{a.id}: {a.tokens:,} actual vs {est:,} estimated ({drift:+.0f}%)")
    tpl, n = tokens_per_loc(d)
    print(f"calibration now {tpl:.0f} tokens/loc over {n} unit(s)")
    if not a.pr:
        print("No PR url — unit returned to pending. Nothing is 'done' without a PR.")


def cmd_hot(a):
    hot, prmeta, cached = hot_files(refresh=a.refresh)
    if not prmeta:
        print("No open PRs (or gh unavailable). No files locked.")
        return
    print(f"{len(hot)} file(s) locked by {len(prmeta)} open PR(s)"
          f"{' [cached]' if cached else ''}:\n")
    for pr in prmeta:
        print(f"  #{pr['number']} {pr['title'][:56]}")
        for f in pr["files"][:6]:
            print(f"      {f}")
        if len(pr["files"]) > 6:
            print(f"      … +{len(pr['files']) - 6} more")


def cmd_sync(a):
    d = load()
    changed = 0
    for uid, u in d["units"].items():
        if u["status"] != "pr-open" or not u.get("pr"):
            continue
        try:
            out = subprocess.run(["gh", "pr", "view", u["pr"], "--json",
                                  "state,mergedAt"], capture_output=True,
                                 text=True, timeout=30)
            if out.returncode:
                print(f"  {uid}: gh failed — {out.stderr.strip()[:60]}")
                continue
            st = json.loads(out.stdout)
            if st.get("mergedAt"):
                u["status"] = "merged"
                changed += 1
                print(f"  {uid}: MERGED")
            elif st.get("state") == "CLOSED":
                u["status"] = "blocked"
                changed += 1
                print(f"  {uid}: closed without merge — needs attention")
            else:
                print(f"  {uid}: still open")
        except Exception as e:
            print(f"  {uid}: {e}")
    save(d)
    print(f"{changed} unit(s) changed state.")


def cmd_checkpoint(a):
    d = load()
    for u in d["units"].values():
        if u["status"] == "active":
            u["status"] = "pending"     # release, don't strand
    d["checkpoints"].append({"note": a.note, "at": now()})
    save(d)
    print("Checkpointed. Next session: run `ledger.py status` first.")


def cmd_report(a):
    d = load()
    lines = ["# Campaign report", "",
             f"Sessions: {d['sessions']}  ·  Units: {len(d['units'])}  ·  "
             f"Merged: {sum(1 for u in d['units'].values() if u['status']=='merged')}",
             ""]
    sev_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    lines.append("## Issues")
    for sev in sorted({i["severity"] for i in d["issues"]},
                      key=lambda s: sev_order.get(s, 9)):
        items = [i for i in d["issues"] if i["severity"] == sev]
        lines.append(f"\n### {sev} ({len(items)})")
        for i in items:
            mark = " **[deferred]**" if i.get("deferred") else ""
            lines.append(f"- `{i['unit']}` — {i['text']}{mark}")
    lines += ["", "## Cross-cutting findings", ""]
    lines += [f"- {f['text']}" for f in d["findings"]]
    out = "\n".join(lines)
    with open(os.path.join(DIR, "report.md"), "w") as f:
        f.write(out)
    print(out)


def main():
    p = argparse.ArgumentParser(prog="ledger.py")
    s = p.add_subparsers(dest="cmd", required=True)

    x = s.add_parser("init"); x.add_argument("--repo", default=None)
    x.set_defaults(fn=cmd_init)

    x = s.add_parser("scan"); x.add_argument("--pattern", required=True)
    x.set_defaults(fn=cmd_scan)

    x = s.add_parser("add"); x.add_argument("id")
    x.add_argument("--files"); x.add_argument("--loc", type=int)
    x.add_argument("--complexity", type=int, choices=[1, 2, 3, 4, 5])
    x.add_argument("--depends-on", nargs="*", default=None)
    x.set_defaults(fn=cmd_add)

    s.add_parser("status").set_defaults(fn=cmd_status)

    x = s.add_parser("next"); x.add_argument("--remaining-tokens", type=int)
    x.add_argument("--refresh-prs", action="store_true",
                   help="bypass the 30-min cache and re-query gh")
    x.set_defaults(fn=cmd_next)

    x = s.add_parser("start"); x.add_argument("id"); x.set_defaults(fn=cmd_start)

    x = s.add_parser("issue"); x.add_argument("unit")
    x.add_argument("--severity", default="medium",
                   choices=["critical", "high", "medium", "low"])
    x.add_argument("--text", required=True)
    x.add_argument("--deferred", action="store_true")
    x.set_defaults(fn=cmd_issue)

    x = s.add_parser("finding"); x.add_argument("--text", required=True)
    x.set_defaults(fn=cmd_finding)

    x = s.add_parser("finish"); x.add_argument("id")
    x.add_argument("--tokens", type=int, required=True); x.add_argument("--pr")
    x.set_defaults(fn=cmd_finish)

    s.add_parser("sync").set_defaults(fn=cmd_sync)

    x = s.add_parser("hot"); x.add_argument("--refresh", action="store_true")
    x.set_defaults(fn=cmd_hot)

    x = s.add_parser("checkpoint"); x.add_argument("--note", required=True)
    x.set_defaults(fn=cmd_checkpoint)

    s.add_parser("report").set_defaults(fn=cmd_report)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
