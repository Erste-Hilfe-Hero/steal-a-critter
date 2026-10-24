# ⚔️ Colosseum Catcher

Fange eigene Bestien in vier Zonen, trainiere dein Team und besiege die 8 Champions des Kolosseums.
Alle Bestien, Namen und Grafiken sind eigene Entwuerfe.

## Spielablauf
- Starter waehlen (Feuer, Wasser oder Blatt), dann wilde Bestien in den Zonen bekaempfen und mit Orbs fangen.
- 24 Bestien in 5 Seltenheiten, 8 Elemente mit Staerken und Schwaechen, Aufstieg in staerkere Formen.
- PRISMATISCHE Bestien sind sehr selten und 20 % staerker.
- 8 Champions geben Abzeichen (Crests), die neue Zonen oeffnen.
- Endloser Gauntlet mit Bestenliste, Duelle gegen andere Spieler (Trophaeen).
- Taegliche Truhe (7-Tage-Serie) und Codes: COLOSSEUM, CATCHEMALL, BIGBABA.

## Geld verdienen
- 8 Dauer-Paesse (VIP, 2x Coins, 2x XP, Big Team, Prismatic Hunter, Lucky Catcher, Auto Battle, Speed).
- 15 Produkte (Master Orbs, Starter Pack, Coin-Pakete, Boost, Power Snack, Ascension Crystal, Champion Pass,
  Full Heal, Gauntlet Second Chance, Prismatic Storm fuer alle, Storage).
- Angebote im richtigen Moment (z. B. Master Orb nach Fehlwurf auf seltene Bestie, Second Chance im Gauntlet).
- Video-Werbung fuer gratis Great Orbs und Werbetafeln in der Welt.
- Zufalls-Produkte werden automatisch versteckt, wo das Land es verlangt (PolicyService).

## Technik
- Rojo-Projekt (`default.project.json`), Code in `src/`, Test in `tests/smoke.luau`.
- Veroeffentlichung: `.github/workflows/publish-colosseum.yml` legt die Produkte aus `products.json` an,
  setzt Name und Beschreibung aus `experience.json` und veroeffentlicht in Universe `10772779368`.
- Icon und Thumbnail: `assets/icon.png`, `assets/thumbnail.png` (erzeugt mit `assets/make_art.py`).
  Diese muessen einmal von Hand im Creator Hub hochgeladen werden.
