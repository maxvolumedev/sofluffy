#!/usr/bin/env python3
"""Usage: bench/compare.py <baseline-label> <candidate-label>
Compares the median across runs of the per-run mean (and p95) for every scenario and metric."""
import glob, json, os, statistics, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
SERIES = ["frame_ms", "gpu_ms", "render_cpu_ms", "script_process_ms", "script_physics_ms", "draw_calls"]
SCALARS = ["load_ms", "texture_mem_mb", "video_mem_mb"]

def load(label):
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, label, "*.json"))):
        d = json.load(open(path))
        row = out.setdefault(d["scenario"], {})
        for k in SERIES:
            row.setdefault(k, []).append(d[k]["mean"])
            row.setdefault(k + "_p95", []).append(d[k]["p95"])
        for k in SCALARS:
            row.setdefault(k, []).append(d[k])
    return {s: {k: (statistics.median(v), min(v), max(v)) for k, v in row.items()} for s, row in out.items()}

a_label, b_label = sys.argv[1], sys.argv[2]
a, b = load(a_label), load(b_label)
for s in a:
    if s not in b:
        continue
    print(f"\n== {s}")
    print(f"{'metric':<18}{a_label:>12}{b_label:>12}{'change':>9}   spread (min..max)")
    for k in a[s]:
        x, xlo, xhi = a[s][k]
        y, ylo, yhi = b[s][k]
        pct = (y - x) / x * 100 if x else 0.0
        print(f"{k:<18}{x:>12.3f}{y:>12.3f}{pct:>+8.1f}%   {xlo:.3f}..{xhi:.3f} -> {ylo:.3f}..{yhi:.3f}")
