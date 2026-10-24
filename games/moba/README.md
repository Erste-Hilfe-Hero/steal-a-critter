# Lanebreakers: Hero Arena – 5v5-MOBA für Handy und PC

Ein kompaktes Helden-Arena-Spiel im Stil von League of Legends, aber mit eigenem Namen, eigenen Helden und eigener Optik. Alles ist per Code gebaut, keine fremden Assets. Ziel: Einnahmen über Helden, Skins, Pässe, Kristalle und Video-Werbung bei einer Mild-(9+)-Einstufung (Fantasy-Kampf ohne Blut).

## Spielprinzip

- **5 gegen 5**, Team **Dawn** (Gold) gegen Team **Dusk** (Violett). Leere Plätze füllen **Bots**, man kann also sofort allein spielen. Kommt ein Spieler während der Runde dazu, übernimmt er einen Bot mit dessen Stufe, Gold und Items.
- **Eine kompakte Karte**: schwebende Insel mit 3 Lanes, Fluss, Dschungel. Pro Team 6 Türme (2 pro Lane) und ein Kern. Die zweite Turmreihe und der Kern sind geschützt, bis die Türme davor fallen.
- **Minion-Wellen** alle 30 Sekunden (Nahkampf, Fernkampf, jede 3. Welle ein Belagerungs-Golem).
- **Dschungel**: Gold-Käfer und Kristall-Irrlichter, in der Mitte der **Sky Titan** (Team-Buff +25 % Kraft) und der **Treasure Golem** (Gold für das ganze Team).
- **Kurze Runden** (ca. 10–15 Minuten): ab Minute 12 werden Minions stärker, nach 20 Minuten gewinnt das Team mit mehr zerstörten Türmen.
- **Handy-freundlich**: Kamera von schräg oben (Gegnerbasis immer oben), automatischer Angriff, Gegner antippen = Fokus, Fähigkeiten zielen automatisch (am PC auf die Maus), Auto-Buy für Items, Rückruf-Knopf.

## Helden

| Held | Rolle | Freischalten |
|---|---|---|
| ✊ Brakka – The Mountain Fist | Tank | gratis |
| ✨ Lumi – Starlight Mage | Mage | gratis |
| 🏹 Pip – Ember Archer | Marksman | gratis |
| 🗡️ Vexa – Shadow Blade | Assassin | 450 💎 oder 99 R$ |
| ❄️ Tundra – Frost Warden | Tank | 450 💎 oder 99 R$ |
| 🌿 Thorne – Grove Keeper | Support | 550 💎 oder 99 R$ |
| 🌪️ Zephyr – Wind Ranger | Marksman | 650 💎 oder 149 R$ |
| ⚡ Volt – Storm Duelist | Fighter | 800 💎 oder 149 R$ |

Jeder Held hat 3 Fähigkeiten (Q, E, R) aus 10 Typen: Kreis, Zielpunkt, Skillshot, Sprung, Einzelziel, Kettenblitz, Schild, Heilung, Buff, Zone. Alle Werte stehen in `src/shared/Config.luau`.

## Monetarisierung

| Produkt | Preis | Wirkung |
|---|---|---|
| Starter Pack (einmalig) | 79 R$ | Volt + Inferno-Skin + 500 Kristalle |
| VIP (dauerhaft) | 299 R$ | +50 % Kristalle, goldener Name, VIP-Tag im Chat |
| 2x Crystals (dauerhaft) | 249 R$ | doppelte Kristalle aus jeder Runde |
| All Heroes | 399 R$ | alle Helden, auch künftige |
| 5 Helden einzeln | 99–149 R$ | Held sofort freischalten |
| 4 Skins (für alle Helden) | 149–349 R$ | Inferno, Frost Crystal, Royal Gold, Galaxy (Crimson gibt es für 1500 Kristalle) |
| Kristall-Pakete | 49 / 149 / 399 R$ | 250 / 900 / 2800 Kristalle |
| Instant Respawn | 15 R$ | sofort wieder ins Spiel (Knopf im Todesbildschirm) |
| Video-Werbung (freiwillig) | – | 40 Kristalle, höchstens alle 5 Minuten |

Dazu: Tagesbelohnung mit Serie (bis 300 Kristalle am 7. Tag), Bonus für den ersten Sieg am Tag, Angebote nach der Runde (höchstens eins alle 3 Minuten, mit „No thanks“). Kein bezahlter Zufall. Items in der Runde gibt es nur für Gold, nicht für Robux.

## Veröffentlichen

Läuft über `.github/workflows/publish-moba.yml`:

1. Experience aus `roblox.json` (Ali's Experience „3“, Universe 10772779235), Place-ID über das Inventar des Besitzers.
2. Fehlende Developer Products aus `products.json` anlegen, IDs nach `src/shared/ProductIds.json`.
3. Name, Beschreibung und Servergröße (10) aus `experience.json` setzen.
4. Mit Rojo bauen, als „Saved“-Version hochladen und darauf `tests/smoke.luau` laufen lassen: eine echte Bot-Runde für eine Minute (Wellen, Gold, Fähigkeiten, Tod und Respawn, Laufzeitfehler).
5. Nur wenn der Test grün ist: live schalten. Bei Pull Requests wird getestet, aber nichts live geschaltet.

Icon und Vorschaubild (`assets/`, erzeugt mit `assets/make_art.py`) lädt `media.yml` hoch.

## Projektstruktur (Rojo)

```
src/shared/Config.luau             ← Helden, Fähigkeiten, Items, Karte, Belohnungen, Produkte
src/server/Services/
  CombatService.luau               ← Einheiten, Schaden, Schilde, Betäubung, Angriffe
  WorldService.luau                ← Arena, Licht, Modelle für Türme, Minions, Monster, Heldenwaffen
  LaneService.luau                 ← Türme, Kerne, Minion-Wellen, Dschungel-Monster
  HeroService.luau                 ← Heldenwerte, Stufen, Gold, Items, Fähigkeiten, Tod, Rückruf
  BotService.luau                  ← Bot-KI (Lane halten, kämpfen, zurückziehen)
  MatchService.luau                ← Heldenwahl, Teams, Rundenablauf, Belohnungen
  MonetizationService.luau         ← Produkte, Kristall-Käufe, Skins, Tagesbonus, Video-Werbung
  DataService.luau                 ← Speichern
src/client/
  UI.luau                          ← Heldenwahl, HUD, Minimap, Item-Shop, Store, Anzeigetafel, Ergebnis
  CameraController.luau            ← MOBA-Kamera, Zielen, Fokus antippen
  Bars.luau                        ← Lebensbalken
  Fx.luau                          ← Effekte und Schadenszahlen
src/first/LoadingScreen.client.luau
tests/smoke.luau
```
