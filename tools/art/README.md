# 3D-Icons und Thumbnails

Alle Icons (512x512) und Vorschaubilder (1920x1080) der Spiele werden hier als echte 3D-Szenen mit Blender gerendert:
blockige Roblox-Figuren, glaenzende Materialien, Licht von mehreren Seiten und eine dicke 3D-Titelschrift mit Kontur.

- `rblx.py` – gemeinsame Bausteine (Figur `noob`, `critter`, `title`, Kamera, Licht, Nachbearbeitung)
- `scenes/<spiel>.py` – eine Szene pro Spiel, rendert `thumbnail.png` und `icon.png`
- `fonts/` – Schriften (Lilita One, Luckiest Guy, Titan One, Fredoka, Bangers; alle SIL Open Font License)
- `render_all.sh` – rendert die fuenf ersten Spiele direkt in ihre Asset-Ordner

## Rendern

Blender gibt es als Python-Paket (`bpy`, braucht Python 3.13):

```bash
python3.13 -m venv /tmp/bpy && /tmp/bpy/bin/pip install bpy numpy pillow
/tmp/bpy/bin/python tools/art/scenes/obby.py --out games/obby/assets            # beide Bilder
/tmp/bpy/bin/python tools/art/scenes/obby.py --out /tmp/test --fast thumb       # schnelle Vorschau
```

Ein Vorschaubild braucht auf 4 CPU-Kernen etwa 5–8 Minuten. Danach laedt `media.yml` die Bilder ueber `media.json` hoch.
Die alten `make_art.py`-Skripte in den Spielordnern erzeugen die fruehere 2D-Grafik und werden nicht mehr gebraucht.
