#!/usr/bin/env python3
"""Kopiert den gemeinsamen Ladebildschirm-Kern (LoadingKit.luau) und die Bild-IDs in alle Spiele.

Jedes Spiel hat src/first/LoadingScreen.client.luau mit einem Block zwischen
"-- >>> LoadingKit" und "-- <<< LoadingKit". Dieser Block wird ersetzt.
Mit --check wird nur geprueft, ob alle Kopien aktuell sind (Exit-Code 1 sonst).
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
KIT = (ROOT / "tools/loading/LoadingKit.luau").read_text().strip("\n")
BLOCK = re.compile(r"-- >>> LoadingKit\n.*?-- <<< LoadingKit", re.S)
IMAGE_BLOCK = re.compile(r"-- >>> LoadingImages[^\n]*\n.*?-- <<< LoadingImages", re.S)
IMAGES_FILE = ROOT / "tools/loading/images.json"
IMAGES = json.loads(IMAGES_FILE.read_text()) if IMAGES_FILE.exists() else {}


def game_key(path: pathlib.Path) -> str:
    parts = path.relative_to(ROOT).parts
    return parts[1] if parts[0] == "games" else "critter"


def image_block(path: pathlib.Path) -> str:
    entry = IMAGES.get(game_key(path), {})
    fields = ", ".join(f'{k} = "{entry.get(k, "")}"' for k in ("left", "right", "icon"))
    return (
        "-- >>> LoadingImages (3D-Vorschaubild in zwei Haelften + Icon, aus tools/loading/images.json)\n"
        f"local IMAGES = {{ {fields} }}\n"
        "-- <<< LoadingImages"
    )


def targets():
    yield ROOT / "src/first/LoadingScreen.client.luau"
    yield from sorted(ROOT.glob("games/*/src/first/LoadingScreen.client.luau"))


def main() -> int:
    check = "--check" in sys.argv
    stale = []
    for path in targets():
        source = path.read_text()
        if not BLOCK.search(source):
            print(f"no LoadingKit block: {path.relative_to(ROOT)}")
            stale.append(path)
            continue
        updated = BLOCK.sub(lambda _: KIT, source, count=1)
        if IMAGE_BLOCK.search(updated):
            updated = IMAGE_BLOCK.sub(lambda _: image_block(path), updated, count=1)
        else:
            updated = updated.replace("-- <<< LoadingKit", "-- <<< LoadingKit\n" + image_block(path), 1)
        if updated != source:
            stale.append(path)
            if not check:
                path.write_text(updated)
                print(f"updated {path.relative_to(ROOT)}")
    if check and stale:
        print("out of date:", ", ".join(str(p.relative_to(ROOT)) for p in stale))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
