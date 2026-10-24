#!/usr/bin/env python3
"""Kopiert den gemeinsamen Ladebildschirm-Kern (LoadingKit.luau) in alle Spiele.

Jedes Spiel hat src/first/LoadingScreen.client.luau mit einem Block zwischen
"-- >>> LoadingKit" und "-- <<< LoadingKit". Dieser Block wird ersetzt.
Mit --check wird nur geprueft, ob alle Kopien aktuell sind (Exit-Code 1 sonst).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
KIT = (ROOT / "tools/loading/LoadingKit.luau").read_text().strip("\n")
BLOCK = re.compile(r"-- >>> LoadingKit\n.*?-- <<< LoadingKit", re.S)


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
