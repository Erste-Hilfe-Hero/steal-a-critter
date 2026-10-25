#!/usr/bin/env python3
"""Laedt die 3D-Vorschaubilder und Icons der Spiele als Roblox-Bilder hoch (fuer die Ladebildschirme).

Das Vorschaubild (1920x1080) wird in zwei Haelften (je 960x1080) geteilt, weil Roblox Bilder auf
1024 Pixel Kantenlaenge verkleinert; so bleibt es fast in voller Aufloesung scharf.
Ergebnis: tools/loading/images.json  {spiel: {left, right, icon}}. Vorhandene Eintraege bleiben.
Braucht ROBLOX_API_KEY und Pillow; laeuft in .github/workflows/loading-images.yml.
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/loading/images.json"
OWNER = "2979321382"
GAMES = {"critter": ROOT / "assets"}
for folder in sorted((ROOT / "games").iterdir()):
    if (folder / "assets/thumbnail.png").exists():
        GAMES[folder.name] = folder / "assets"


def upload(path: pathlib.Path, name: str) -> str:
    request = json.dumps({
        "assetType": "Image",
        "displayName": name[:50],
        "description": "Loading screen art",
        "creationContext": {"creator": {"userId": OWNER}},
    })
    key = os.environ["ROBLOX_API_KEY"]
    raw = subprocess.run(
        ["curl", "-sS", "-X", "POST", "https://apis.roblox.com/assets/v1/assets", "-H", f"x-api-key: {key}",
         "-F", f"request={request}", "-F", f"fileContent=@{path};type=image/png"],
        capture_output=True, text=True).stdout
    try:
        operation = json.loads(raw).get("path")
    except ValueError:
        operation = None
    if not operation:
        print(f"::warning::{name}: upload failed: {raw[:300]}")
        return ""
    for _ in range(20):
        time.sleep(2)
        raw = subprocess.run(["curl", "-sS", f"https://apis.roblox.com/assets/v1/{operation}", "-H", f"x-api-key: {key}"],
                             capture_output=True, text=True).stdout
        try:
            result = json.loads(raw)
        except ValueError:
            continue
        if result.get("done"):
            asset = str(result.get("response", {}).get("assetId", ""))
            print(f"::notice::{name}: {asset or raw[:300]}")
            return asset
    print(f"::warning::{name}: operation not done: {raw[:300]}")
    return ""


def main() -> int:
    images = json.loads(OUT.read_text()) if OUT.exists() else {}
    with tempfile.TemporaryDirectory() as tmp:
        for game, folder in GAMES.items():
            entry = images.setdefault(game, {})
            thumb = Image.open(folder / "thumbnail.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)
            parts = {
                "left": thumb.crop((0, 0, 960, 1080)),
                "right": thumb.crop((960, 0, 1920, 1080)),
                "icon": Image.open(folder / "icon.png").convert("RGBA"),
            }
            for part, picture in parts.items():
                if entry.get(part):
                    continue
                path = pathlib.Path(tmp) / f"{game}_{part}.png"
                picture.save(path)
                entry[part] = upload(path, f"{game} loading {part}")
                time.sleep(1)
    OUT.write_text(json.dumps(images, indent=2) + "\n")
    missing = [f"{g}.{p}" for g, e in images.items() for p in ("left", "right", "icon") if not e.get(p)]
    if missing:
        print("::warning::missing: " + ", ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
