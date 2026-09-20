#!/bin/sh
# Usage: bench/run.sh <label> [scenario...]
# Runs every scenario REPS times (default 3), interleaved, and writes JSON to bench/results/<label>/.
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
REPS=${REPS:-3}
label=${1:?usage: bench/run.sh <label> [scenario...]}
shift
[ $# -gt 0 ] || set -- fill grid_lod grid_physics grid_all
out="$PWD/bench/results/$label"
mkdir -p "$out"
for r in $(seq "$REPS"); do
	for s in "$@"; do
		echo "[$label] $s run $r"
		"$GODOT" --path . --disable-vsync --resolution 1280x720 res://bench/bench.tscn -- \
			"scenario=$s" "out=$out/$s.$r.json" >/dev/null 2>"$out/$s.$r.err" || echo "  FAILED, see $out/$s.$r.err"
	done
done
