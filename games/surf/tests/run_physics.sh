#!/bin/sh
# Fuehrt den Physik-Test im luau-CLI aus: Vector3-Ersatz + SurfPhysics + Test in einer Datei
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)/physics_all.luau
{
	echo "local Vector3 = (function()"; cat tests/vector3.luau; echo "end)()"
	echo "local SurfPhysics = (function()"; cat src/shared/SurfPhysics.luau; echo "end)()"
	cat tests/physics.luau
} > "$OUT"
${LUAU:-luau} "$OUT"
