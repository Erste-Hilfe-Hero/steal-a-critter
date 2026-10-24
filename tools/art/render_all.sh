#!/usr/bin/env bash
# Rendert alle Icons und Thumbnails direkt in die Asset-Ordner der Spiele.
# Aufruf: tools/art/render_all.sh [python-mit-bpy] [szene ...]
set -euo pipefail
cd "$(dirname "$0")/../.."
PY=${1:-python3}; shift || true
declare -A OUT=([steal]=assets [obby]=games/obby/assets [petsim]=games/petsim/assets [tycoon]=games/tycoon/assets [soccer]=games/soccer/assets)
for s in "${@:-steal obby petsim tycoon soccer}"; do
  for n in $s; do
    echo "== $n -> ${OUT[$n]}"
    "$PY" "tools/art/scenes/$n.py" --out "${OUT[$n]}"
  done
done
