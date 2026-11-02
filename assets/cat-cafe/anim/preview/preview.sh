#!/usr/bin/env bash
# Renders cat motion scenarios to clips: ./preview.sh "<scenario> [<scenario> ...]" <out dir> [render.py options]
# Needs rojo, lune, ffmpeg and a python with bpy on PATH (or PYTHON=/path/to/python). See README.md.
set -euo pipefail
cd "$(dirname "$0")"
scenarios=$1
out=$2
shift 2
mkdir -p "$out"
rojo build preview.project.json -o "$out/cats.rbxm"
for scenario in $scenarios; do
	lune run dump.luau "$out/cats.rbxm" "$scenario" "$out/$scenario.json"
	"${PYTHON:-python3}" render.py "$out/$scenario.json" "$out" "$@"
done
