#!/bin/sh
# Bot-Test aller Stages im luau-CLI: Vector3-Ersatz + SurfPhysics + StageLayout + Stage-Liste aus Config
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)/stages_all.luau
{
	echo "local Vector3 = (function()"; cat tests/vector3.luau; echo "end)()"
	echo "local SurfPhysics = (function()"; cat src/shared/SurfPhysics.luau; echo "end)()"
	echo "local StageLayout = (function()"; cat src/shared/StageLayout.luau; echo "end)()"
	echo "local SurfAssist = (function()"; cat src/shared/SurfAssist.luau; echo "end)()"
	echo "local Color3 = { fromRGB = function() return {} end }"
	echo "local Arena = (function()"; cat src/shared/Arena.luau; echo "end)()"
	echo "local Stages = (function()"
	sed -n '/^Config.Stages = {/,/^}/p' src/shared/Config.luau | sed 's/^Config.Stages = /return /'
	echo "end)()"
	grep -E '^Config\.Stage(Spacing|Height) =' src/shared/Config.luau | sed 's/^Config\./local /'
	cat tests/stages.luau
} > "$OUT"
${LUAU:-luau} "$OUT"
