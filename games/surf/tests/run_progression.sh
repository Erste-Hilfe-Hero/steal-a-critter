#!/bin/sh
# Test der Fortschritts-Daten im luau-CLI: Color3-Ersatz + Progression + Test in einer Datei
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)/progression_all.luau
{
	echo "local Color3 = { fromRGB = function() return {} end }"
	echo "local Progression = (function()"; cat src/shared/Progression.luau; echo "end)()"
	cat tests/progression.luau
} > "$OUT"
${LUAU:-luau} "$OUT"
