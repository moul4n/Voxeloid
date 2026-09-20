#!/usr/bin/env python3
"""
compare.py — diff two bench runs, or one run against the committed reference.

  python tools/compare.py <run_dir>                 # vs bench/reference/<scenario>/summary.json
  python tools/compare.py <run_dir_a> <run_dir_b>   # a = baseline, b = candidate
  python tools/compare.py --all                     # one row per run in the bench folder
  python tools/compare.py --latest [scenario]       # newest run of a scenario vs reference

Exit code 1 on regression (p99 worse than --threshold, default 5%).
Bench folder is Godot's user://bench; override with --bench <dir>.
"""
import argparse, json, os, sys, glob, platform

def user_bench_dir():
    home = os.path.expanduser("~")
    cands = {
        "Windows": os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "voxbench", "bench"),
        "Darwin":  os.path.join(home, "Library", "Application Support", "Godot", "app_userdata", "voxbench", "bench"),
        "Linux":   os.path.join(home, ".local", "share", "godot", "app_userdata", "voxbench", "bench"),
    }
    return cands.get(platform.system(), cands["Linux"])

def load(run_dir):
    with open(os.path.join(run_dir, "summary.json")) as f:
        return json.load(f)

def fmt(v):
    if isinstance(v, float): return f"{v:9.2f}"
    return f"{str(v):>9s}"

def delta(a, b, lower_is_better=True):
    try:
        if a in (0, None): return "", False
        d = (b - a) / a
        arrow = "▲" if d > 0 else ("▼" if d < 0 else " ")
        worse = (d > 0) if lower_is_better else (d < 0)
        return f"{d:+7.1%}  {arrow}", worse
    except TypeError:
        return "", False

ROWS = [  # (label, path, lower_is_better)
    ("frame p50 ms", ("frame_ms", "p50"), True),
    ("frame p95 ms", ("frame_ms", "p95"), True),
    ("frame p99 ms", ("frame_ms", "p99"), True),
    ("frame max ms", ("frame_ms", "max"), True),
    ("1% low fps",   ("frame_ms", "low1pct_fps"), False),
    ("process p99",  ("process_ms", "p99"), True),
    ("physics p99",  ("physics_ms", "p99"), True),
    ("draw calls",   ("draw_calls", "avg"), True),
    ("live swarm",   ("live_swarm", "avg"), False),
]
META = ["scenario", "layers", "swarm_path", "gpu", "renderer", "git", "label", "date"]

def get(d, path):
    for p in path:
        d = d.get(p, {}) if isinstance(d, dict) else {}
    return d if not isinstance(d, dict) else None

def compare(a, b, threshold):
    print(f"{'':16s}{'baseline':>12s}{'this run':>12s}{'delta':>14s}")
    regress = False
    for label, path, lib in ROWS:
        va, vb = get(a, path), get(b, path)
        d, worse = delta(va, vb, lib)
        flag = ""
        if label == "frame p99 ms" and va and vb and (vb - va) / va > threshold:
            flag = "  REGRESSION"; regress = True
        print(f"  {label:14s}{fmt(va)}   {fmt(vb)}   {d}{flag}")
    for m in META:
        print(f"  {m:14s}{str(a.get(m,'')):>12s}   {str(b.get(m,'')):>12s}")
    pa, pb = a.get("pass"), b.get("pass")
    print(f"\n  pass: baseline {pa}  this run {pb}")
    print(f"  verdict: {'REGRESSION on p99' if regress else 'ok'} (threshold {threshold:.0%})")
    return regress

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--latest", nargs="?", const="late")
    ap.add_argument("--bench", default=user_bench_dir())
    ap.add_argument("--reference", default=os.path.join(os.path.dirname(__file__), "..", "bench", "reference"))
    ap.add_argument("--threshold", type=float, default=0.05)
    a = ap.parse_args()

    runs = sorted(glob.glob(os.path.join(a.bench, "*", "summary.json")))
    if a.all:
        print(f"{'date':17s}{'scenario':8s}{'git':8s}{'path':5s}{'p50':>7s}{'p99':>7s}{'max':>7s}{'1%low':>7s}  pass  label")
        for p in runs:
            s = load(os.path.dirname(p)); f = s.get("frame_ms", {})
            print(f"{s.get('date',''):17s}{s.get('scenario',''):8s}{s.get('git',''):8s}{s.get('swarm_path',''):5s}"
                  f"{f.get('p50',0):7.2f}{f.get('p99',0):7.2f}{f.get('max',0):7.2f}{f.get('low1pct_fps',0):7.0f}  {str(s.get('pass')):5s} {s.get('label','')}")
        return 0

    if a.latest:
        cands = [p for p in runs if load(os.path.dirname(p)).get("scenario") == a.latest]
        if not cands: print(f"no runs for scenario {a.latest} in {a.bench}"); return 2
        a.runs = [os.path.dirname(cands[-1])]

    if len(a.runs) == 1:
        b = load(a.runs[0])
        ref = os.path.join(a.reference, b.get("scenario", ""), "summary.json")
        if not os.path.exists(ref):
            print(f"no reference for scenario '{b.get('scenario')}' at {ref}\n(commit the first passing run's folder there)")
            return 2
        base = json.load(open(ref))
    elif len(a.runs) == 2:
        base, b = load(a.runs[0]), load(a.runs[1])
    else:
        ap.print_help(); return 2
    return 1 if compare(base, b, a.threshold) else 0

if __name__ == "__main__":
    sys.exit(main())
