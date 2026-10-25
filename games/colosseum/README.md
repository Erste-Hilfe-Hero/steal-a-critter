# ⚔️ Colosseum Catcher

Ein Abenteuer im Stil der klassischen Monster-Spiele: Starter im Labor waehlen, ueber Routen mit hohem Gras
von Stadt zu Stadt reisen, wilde Bestien fangen, 8 Arenaleiter besiegen und Champion der Liga werden.
Alle Bestien, Namen und Grafiken sind eigene Entwuerfe.

## Spielablauf
- Story: Professor Sol in Dawnvale gibt den Starter (Feuer, Wasser oder Blatt), Rivale Kai kaempft viermal gegen dich.
- 9 Staedte, 9 Routen, 8 Arenen mit Arena-Trainern und Leitern, Champion Road, Grand Four und Champion Maximus.
- Team Eclipse als Boesewicht (zwei Bosskaempfe), 5 legendaere Bestien in Schreinen.
- Wilde Bestien nur im hohen Gras, Trainer sehen dich und laufen auf dich zu.
- Rundenkampf wie im Original: 4 Attacken mit AP, Typen-Effektivitaet, Volltreffer, Status (Brand, Gift, Schlaf,
  Paralyse, Frost), Statuswerte, Beutel, Wechseln, Flucht, Fangen mit Wackeln.
- 50 Bestien mit Doppeltypen, Lernsets, Entwicklung und Attacken lernen nach dem Kampf.
- Heilzentrum und Laden in jeder Stadt, Fliegen zu besuchten Staedten, Karte mit Ziel-Markierung, Bestiarium.
- PRISMATISCHE Bestien sind sehr selten und 20 % staerker.
- Endloser Gauntlet, Revanchen gegen Arenaleiter, Duelle gegen Spieler, taegliche Truhe und Codes.

## Geld verdienen
- 8 Dauer-Paesse (VIP, 2x Coins, 2x XP, XP Share, Prismatic Hunter, Lucky Catcher, Auto Battle, Speed).
- 15 Produkte (Master Orbs, Starter Pack, Coin-Pakete, Boost, Power Snack, Ascension Crystal, Champion Pass (naechster Orden),
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

## Update

### Behobene Fehler
1. `MonetizationService.ApplyPassEffects` rief das entfernte `BeastService:TeamSize` auf: jeder Beitritt brach in `LoadPasses` ab, Pass-Kaeufe scheiterten im `ProcessReceipt`.
2. Wer nach der Starterwahl, aber vor dem ersten Rivalenkampf ging, blieb ohne Rivalen-Flags haengen (Kai im Labor, 5 Baelle fehlten) - wird beim Beitritt repariert.
3. `BuyItem` mit NaN-Menge loeschte die Muenzen und speicherte NaN; `SetMove` mit NaN-Platz warf einen Fehler.
4. Verzoegertes Ende einer Rauswurf-Abstimmung konnte eine neuere Abstimmung vorzeitig beenden.
5. Tagesbelohnung vor der Starterwahl gab keine Rueckmeldung.
6. Starter-Auswahl konnte doppelt geoeffnet werden.
7. HUD lag unter den Roblox-Topbar-Knoepfen (jetzt GuiInset beruecksichtigt; Menue 3-spaltig, passt aufs Handy).
8. `experience.json` beschrieb einen veralteten Stand (24 Bestien, 7 Elemente).

### 15 neue Funktionen
1. Taegliche Aufgaben (3 pro Tag, Belohnungen, Bonus fuer alle drei).
2. 17 Erfolge mit Muenzbelohnung und Banner.
3. Titel aus Erfolgen, sichtbar im Namensschild.
4. Bestiarium-Meilensteine (5-50 gefangene Arten) mit Belohnungen.
5. Kostenloses Gluecksrad alle 6 Stunden (keine bezahlten Zufallsgegenstaende).
6. Spielzeit-Geschenke nach 5/15/30/60 Minuten.
7. Bestien-Hort: eine Bestie trainiert offline (bis 8 h) und sammelt EP.
8. Begleiter: die fuehrende Bestie laeuft hinter jedem Spieler her.
9. Schwarm-Ereignisse: zeitweise erscheint eine Bestie gehaeuft auf einer Route.
10. Bestenliste "TOP COLLECTORS" (gefangene Arten).
11. Trainerkarten anderer Spieler (Team, Abzeichen, Siege, Titel).
12. Zielkompass im HUD (naechstes Story-Ziel, oeffnet die Karte).
13. Bestien als Favorit schuetzen (nicht freilassbar, zuerst sortiert).
14. Sortierung der Box (Staerke, Level, Neueste, Typ, Name).
15. Einstellungen (Sounds, Begleiter, fremde Begleiter, Effekte, Kompass) und UI-Sounds.

### Neues Produkt
- `QuestFinish` ("Quest Finisher", R$ 39): erledigt alle offenen Tagesaufgaben sofort.
