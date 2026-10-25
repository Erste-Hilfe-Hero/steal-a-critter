# Lanebreakers: Hero Arena – 5v5-MOBA für Handy und PC

Ein kompaktes Helden-Arena-Spiel im Stil von League of Legends, aber mit eigenem Namen, eigenen Helden und eigener Optik. Alles ist per Code gebaut, keine fremden Assets. Ziel: Einnahmen über Helden, Skins, Pässe, Kristalle und Video-Werbung bei einer Mild-(9+)-Einstufung (Fantasy-Kampf ohne Blut).

## Spielprinzip

- **5 gegen 5**, Team **Dawn** (Gold) gegen Team **Dusk** (Violett). Leere Plätze füllen **Bots**, man kann also sofort allein spielen. Kommt ein Spieler während der Runde dazu, übernimmt er einen Bot mit dessen Stufe, Gold und Items.
- **Rollen und Karte wie im Original**: Top, Jungle, Mid, Bot, Support. 3 Lanes, Fluss, Dschungel. Pro Team 11 Türme, 3 Inhibitoren und ein Nexus. Hintere Türme und der Nexus sind geschützt, bis die Türme davor fallen.
- **Minion-Wellen** alle 30 Sekunden (Nahkampf, Fernkampf, regelmäßig ein Belagerungs-Minion).
- **Dschungel**: Azure Sentinel (blauer Buff), Ember Brambleback (roter Buff), kleine Lager, River Scuttler, vier **Drachen** mit Drachenseele und Elder Drake, der **Siege Herald** und der **Abyss Tyrant** (Team-Buff).
- **Runden** dauern ca. 15–25 Minuten. Ab Minute 25 werden Minions stärker, damit Runden enden. Aufgeben per Abstimmung ab Minute 8.
- **Handy-freundlich**: Kamera von schräg oben (Gegnerbasis immer oben), automatischer Angriff, Gegner antippen = Fokus, Fähigkeiten zielen automatisch (am PC auf die Maus), Auto-Buy für Items, Rückruf-Knopf.

## Helden

| Held | Klasse | Freischalten |
|---|---|---|
| ⛰️ Brakka – The Living Mountain | Tank | gratis |
| ✨ Lumi – Lady of Radiance | Mage | gratis |
| 🚀 Pip – The Loose Cannon | Marksman | gratis |
| 🦂 Vexa – The Void Stalker | Assassin | 450 💎 oder 99 R$ |
| ❄️ Tundra – The Winter's Wrath | Tank | 450 💎 oder 99 R$ |
| 🌿 Thorne – The Starchild | Support | 550 💎 oder 99 R$ |
| 🏹 Zephyr – The Prodigal Archer | Marksman | 650 💎 oder 149 R$ |
| ⚡ Volt – The Storm Blade | Fighter | 800 💎 oder 149 R$ |
| 🪓 Varg – The Iron Wolf | Fighter | 650 💎 oder 149 R$ |
| 🏮 Gaff – The Lantern Warden | Support | 650 💎 oder 149 R$ |
| ☄️ Ember – The Cinder Sage | Mage | 700 💎 oder 149 R$ |

Jeder Held hat eine Passive und 4 Fähigkeiten (Q, W, E, R), dazu zwei Beschwörerzauber (D, F). Alle Werte stehen in `src/shared/Config.luau`.

## Monetarisierung

| Produkt | Preis | Wirkung |
|---|---|---|
| Starter Pack (einmalig) | 79 R$ | Volt + Inferno-Skin + 500 Kristalle |
| VIP (dauerhaft) | 299 R$ | +50 % Kristalle, goldener Name, VIP-Tag im Chat |
| 2x Crystals (dauerhaft) | 249 R$ | doppelte Kristalle aus jeder Runde |
| All Heroes | 449 R$ | alle Helden, auch künftige |
| 8 Helden einzeln | 99–149 R$ | Held sofort freischalten |
| 4 Skins (für alle Helden) | 149–349 R$ | Inferno, Frost Crystal, Royal Gold, Galaxy (Crimson gibt es für 1500 Kristalle) |
| Kristall-Pakete | 49 / 149 / 399 R$ | 250 / 900 / 2800 Kristalle |
| Instant Respawn | 15 R$ | sofort wieder ins Spiel (Knopf im Todesbildschirm; außerhalb der Runde gibt es stattdessen 50 Kristalle) |
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
src/shared/Config.luau             ← Helden, Fähigkeiten, Items, Karte, Belohnungen, Quests, Erfolge, Produkte
src/server/Services/
  CombatService.luau               ← Einheiten, Schaden, Schilde, Betäubung, Angriffe
  Abilities.luau                   ← Fähigkeiten und Passiven aller Helden
  WorldService.luau                ← Arena, Licht, Modelle für Türme, Minions, Monster, Heldenwaffen
  LaneService.luau                 ← Türme, Inhibitoren, Nexus, Minion-Wellen
  JungleService.luau               ← Dschungel-Lager, Drachen, Herald, Abyss Tyrant
  VisionService.luau               ← Nebel des Krieges, Wards
  HeroService.luau                 ← Heldenwerte, Stufen, Gold, Items, Zauber, Tod, Rückruf
  BotService.luau                  ← Bot-KI (Lane halten, kämpfen, zurückziehen)
  MatchService.luau                ← Heldenwahl, Teams, Rundenablauf, Belohnungen, MVP
  MonetizationService.luau         ← Produkte, Kristall-Käufe, Skins, Tagesbonus, Video-Werbung
  ProgressService.luau             ← Konto-Stufe, Meisterschaft, Quests, Erfolge/Titel, Codes, Einstellungen, Emotes, Pings, Bestenliste
  DataService.luau                 ← Speichern
src/client/
  UI.luau                          ← Heldenwahl, HUD, Minimap, Item-Shop, Store, Anzeigetafel, Ergebnis, Pings/Emotes
  Menus.luau                       ← Menü, Quests, Erfolge, Profil, Bestenliste, Codes, Einstellungen, Anleitung
  Controls.luau                    ← Steuerknüppel, Fähigkeiten-Knöpfe, Tastatur
  CameraController.luau            ← MOBA-Kamera, Zoom (auch Pinch am Handy)
  Bars.luau                        ← Lebensbalken und Titel über den Helden
  Fx.luau                          ← Effekte, Schadenszahlen, Emotes, Ping-Markierungen
  Sounds.luau                      ← kurze Klangeffekte (nur eingebaute Roblox-Sounds)
src/first/LoadingScreen.client.luau
tests/smoke.luau
```

## Update

**Behobene Fehler**

1. Tagesbonus-Hinweis (`DailyReady`) blieb nach Mitternacht falsch, bis der Spieler neu beitrat – wird jetzt jede Minute geprüft (neue Quests ebenfalls).
2. „YOU HAVE BEEN SLAIN“ / „YOU HAVE SLAIN AN ENEMY“ verglich Anzeigenamen – bei gleichen Namen (oder Bots mit gleichem Namen) falsche Ansagen. Jetzt per UserId.
3. Pinch-Zoom am Handy war im Kommentar versprochen, aber nicht eingebaut.
4. Ergebnis-Fenster hatte keinen Schließen-Knopf und verdeckte das Bild bis zur nächsten Heldenwahl.
5. Instant Respawn außerhalb der laufenden Runde (Heldenwahl/Ende) verfiel ohne Wirkung – jetzt gibt es dann 50 Kristalle.
6. Flash sprang immer auf volle Reichweite, auch wenn das Ziel näher lag.
7. Granite-Schild startete einstündige Verzögerungs-Threads (Speicherleck über lange Server-Laufzeiten).
8. Heldenauswahl: mit 11 Helden lief das Raster über den Rand – Karten verkleinert.
9. Meldungen (Toasts) ohne Obergrenze liefen bei vielen gleichzeitigen Meldungen aus dem Bild – jetzt höchstens vier.
10. `experience.json` und README waren veraltet (8 Helden, Sky Titan/Treasure Golem, 10–15 Minuten, All Heroes 399 statt 449 R$).

**15 neue Features**

1. Neuer Held **Ember – The Cinder Sage** (Mage, Mid/Support): Fireball, Flame Pillar (Betäubung), Blaze Step, Meteor Storm; Passive *Kindling* setzt Gegner in Brand. 700 💎 oder 149 R$.
2. **Helden-Meisterschaft** (Stufe 1–7) pro Held mit Kristall-Belohnung, sichtbar in der Heldenwahl und im Profil.
3. **Tages-Quests**: 3 zufällige Aufgaben pro Tag mit Fortschritt und Abholen-Knopf (📜 im Menü mit Hinweis-Punkt).
4. **Erfolge mit Titeln**: 13 Erfolge, freigeschaltete Titel kann man tragen – über dem Helden, in der Anzeigetafel und im Chat.
5. **Konto-Stufe** mit XP-Balken, Kristalle bei jedem Aufstieg (jede 5. Stufe mehr).
6. **Profil**: Lebenszeit-Statistik (Siege, Siegquote, KDA, CS, Türme, Wards, MVP, Serie) und Meisterschaft aller Helden.
7. **Siegesserie**: ab dem 2. Sieg in Folge Bonus-Kristalle (bis +50).
8. **MVP** pro Team am Rundenende (+30 Kristalle, Ansage für das Sieger-Team).
9. **Team-Pings** (📍): Angreifen, Vorsicht, Komme, Hilfe, Gegner fehlt – Markierung in der Welt, auf der Minimap und als Meldung.
10. **Emotes** (😄) über dem eigenen Helden, für alle sichtbar.
11. **Codes** (☰ → Codes): LANEBREAKERS, FIRSTBLOOD, DRAGONSOUL, jeder einmal pro Konto.
12. **Einstellungen** (gespeichert): Sound an/aus, Schadenszahlen an/aus, Kamera-Abstand.
13. **Klangeffekte** für Knöpfe, Pings, Emotes, Kills, Stufenaufstieg, Sieg und Niederlage.
14. **Anleitung** „How to play“ in 7 Seiten, öffnet sich für neue Spieler automatisch.
15. **Bestenliste** der meisten Siege aller Spieler (OrderedDataStore, alle 2 Minuten aktualisiert).

Neues Produkt: `Hero_Ember` (149 R$) in `products.json`.
