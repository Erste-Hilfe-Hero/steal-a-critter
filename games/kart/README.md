# Fire Blaster Race – Kart-Rennspiel mit Fokus auf Einnahmen

Ein Kart-Racer im Stil der großen Fun-Racer: Karts, Item-Boxen, Drift-Turbo und 10 Strecken. Alles ist selbst gebaut und eigenständig: eigene Namen, eigene Karts aus Parts, eigene Items, keine fremden Figuren oder Assets.

## Spielablauf

1. **Lobby (Sky Garage)** über der Strecke: Logo-Wand, Bestenliste (Siege), Kart-Showroom auf Drehtellern, Status-Anzeige.
2. **Abstimmung** (22 s): 3 zufällige Strecken, jeder stimmt ab. Mit Robux: *Pick Next Track* (beliebige Strecke) oder *Start Race Now*.
3. **Start**: bis zu 8 Fahrer, freie Plätze füllen CPU-Fahrer (klar als CPU markiert), damit man auch allein sofort fahren kann. Startampel mit **Raketenstart** (Gas beim letzten Licht).
4. **Rennen** (3 Runden): Drift (halten + lenken) lädt Turbo in Blau, Orange, Lila. Boost-Pads, Münzen (+1 % Tempo pro Münze, max. 10), Item-Boxen.
5. **Ergebnis**: Münzen nach Platz (300 bis 60) plus eingesammelte Münzen, mal Multiplikatoren. Sieg zählt für die Bestenliste.

## Strecken

Blaster Speedway, Lava Loop, Candy Canyon, Frost Peak, Neon Night City, Jungle Ruins, Desert Dunes, Star Highway (Achterschleife mit Brücke im All), Sunny Bay, Haunted Hollow. Jede mit eigenem Licht, Boden, Curbs, Wänden und Deko. Die Formen stehen in `src/shared/TrackPoints.luau`.

## Items

Fire Boost (1x/2x/3x), Fireball (prallt von Wänden ab), Homing Blaster (verfolgt den Fahrer vor dir), Oil Slick, Flame Shield, Inferno Mode (unverwundbar + schnell), Thunder Blast (trifft alle vor dir). Wer hinten liegt, bekommt stärkere Items.

## Monetarisierung

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 299 R$ | x1,5 Münzen, goldener Name, Golden-Inferno-Flammen |
| Dauerhaft | 2x Coins | 399 R$ | doppelte Münzen |
| Dauerhaft | Inferno GT | 499 R$ | schnellstes Kart |
| Dauerhaft | Rocket Start | 149 R$ | immer perfekter Raketenstart |
| Dauerhaft | Item Pockets | 249 R$ | 2 Items gleichzeitig |
| Produkt | Coin Stack / Bag / Chest / Vault | 49 / 179 / 499 / 1299 R$ | 2K / 9K / 35K / 120K Münzen |
| Produkt | 3 Inferno Items | 49 R$ | Inferno Mode jederzeit im Rennen zünden |
| Produkt | Coin Party | 99 R$ | 10 min 2x Münzen für den ganzen Server |
| Produkt | Pick Next Track / Start Race Now | 39 / 19 R$ | Impulskäufe in der Abstimmung |
| Produkt | Starter Pack (einmalig) | 79 R$ | 6.000 Münzen, 3 Inferno, Blue Plasma |
| Werbung | Free Coins (Video) | – | 400 Münzen pro freiwilliger Werbung |

Dazu: Angebote nach dem Rennen (höchstens alle 3 Minuten, mit "No thanks"), Münz-Angebot wenn ein Kart zu teuer ist, Premium-Bonus +20 %, +10 % pro Freund im Server, tägliche Belohnung und Spielzeit-Geschenk. Kein bezahlter Zufall.

## Technik

- `src/server/Services`: `TrackService` (Streckenbau), `RaceService` (Ablauf, CPU, Items, Runden), `LobbyService`, `MonetizationService`, `ShopService`, `DataService`.
- `src/shared/KartPhysics.luau`: Arcade-Fahrphysik (der Client ist Network Owner seines Karts; der Smoke-Test nutzt dieselbe Physik).
- `src/client`: `KartController` (Eingabe, Kamera), `UI` (gesamte Oberfläche), Ladebildschirm in `src/first`.
- `assets/make_art.py`: erzeugt `logo.png`, `icon.png`, `thumbnail.png` (Schrift Sarpanch Black).
- Veröffentlichen: `.github/workflows/publish-kart.yml` findet die Experience über den Namen ("Blaster"), legt die Produkte an, lädt eine Saved-Version hoch, lässt `tests/smoke.luau` auf Roblox laufen (alle Strecken vermessen, Testfahrten, CPU-Rennen) und schaltet erst bei 0 Fehlern live.
- `src/shared/Progression.luau` (Level, Aufgaben, Erfolge, Einstellungen) und `src/server/Services/ProgressService.luau` (Update 2).

## Update 2: Fehlerbehebungen und 15 neue Funktionen

### Behobene Fehler

1. **Runden-Schummeln**: Der Server hat jede Kart-Position akzeptiert (der Client steuert sein Kart). Wer sich teleportierte, konnte Runden und Siege fälschen. Jetzt zählt Fortschritt nach vorne nur so weit, wie ein Kart in der Zeit fahren kann.
2. **Platz-Sortierung**: Ausgeschiedene Fahrer (DNF) machten die Sortierfunktion widersprüchlich (Fehler "invalid order function" oder falsche Plätze). Jetzt feste Reihenfolge: im Ziel, fahrend, ausgeschieden.
3. **Inferno-Rammen** traf denselben Gegner 10-mal pro Sekunde (Dauerdrehen, jedes Mal -2 Münzen). Wer sich gerade dreht, kann nicht erneut getroffen werden.
4. **Heartbeat-Leck**: Brach ein Rennen mit einem Fehler ab, lief die Renn-Schleife für immer weiter. Wird jetzt beim Aufräumen getrennt.
5. **Kein Ergebnis für ausgeschiedene Fahrer** (z. B. Figur gestorben): Sie sahen gar kein Ergebnisfenster. Jetzt sehen sie die Tabelle.
6. **Gekauftes Inferno-Item** setzte die Wartezeit des gehaltenen Items zurück. Wird jetzt wiederhergestellt.
7. **Boosting-Remote** ließ sich spammen (jedes Mal Suche durch alle Kart-Teile). Jetzt nur bei echtem Wechsel.
8. **"Start Race Now"** konnte außerhalb der Abstimmung gekauft werden und übersprang dann die nächste Abstimmung komplett. Jetzt nur während der Abstimmung.
9. **Lauftempo 22** fehlte bei der ersten Figur, wenn sie erschien, während die Daten noch luden.
10. **Datenladen**: Ein kaputter Speicherstand (keine Tabelle) ließ das Laden abstürzen; neue Felder in verschachtelten Tabellen werden jetzt ergänzt.
11. **Komplett stumm**: Das Spiel hatte keinen einzigen Sound (siehe Funktion 11).

### 15 neue Funktionen

1. **Fahrer-Level und XP**: XP für jedes Rennen (Platz 1 am meisten) und jede Aufgabe. Level-Aufstieg gibt Münzen (100 x Level). Level mit XP-Balken unter den Münzen und auf dem Kart-Namensschild.
2. **Tägliche Aufgaben**: 3 Aufgaben pro Tag (z. B. "Blast 5 rivals", "Open 12 item boxes") mit Fortschrittsbalken, CLAIM-Knopf und Zähler-Abzeichen im Menü.
3. **Erfolge mit Titeln**: 10 Erfolge (erster Sieg, 10/50 Siege, 50 Rennen, 50 Treffer, 500 Strecken-Münzen, 3 Siege in Folge, Level 10, alle Strecken) mit Münzen und freischaltbarem Titel.
4. **Namensschild in der Lobby**: Level und gewählter Titel schweben über jedem Spieler.
5. **Siegesserie**: Ab dem 2. Sieg in Folge Bonus-Münzen (bis +250), ab 3 Siegen Ansage an alle ("ON FIRE").
6. **Persönliche Bestzeiten** pro Strecke, "NEW PERSONAL BEST" im Ergebnisfenster.
7. **Streckenrekorde in der Lobby**: Neue Tafel "TRACK RECORDS" mit der schnellsten Zeit jeder Strecke (über alle Server).
8. **Profil-Fenster**: Statistik (Level, Siege, Rennen, Podien, Serie, Treffer, Spielzeit ...), Titel ausrüsten, Bestzeiten aller Strecken.
9. **Lackierungen**: 7 Lacke für das eigene Kart (Pearl White bis Gold Rush) in der Garage unter "Paint", mit Münzen.
10. **Einstellungen**: Sound, Kamerawackeln, Zoom-Effekt, Minimap und Steuerungs-Hinweise an/aus (gespeichert).
11. **Soundeffekte**: Countdown-Pieptöne, GO, Boost, Treffer, Münzen, Items, Ziel, Level-Aufstieg, Knöpfe (nur eingebaute Roblox-Sounds).
12. **Tutorial "How to Play"**: Erscheint beim ersten Besuch (Handy- oder PC-Steuerung), +200 Münzen beim Abschluss, jederzeit in den Einstellungen.
13. **Raketenstart auf dem Handy**: Großer GAS-Knopf im Countdown (zu früh = kein Raketenstart). Vorher konnten Handy-Spieler nie einen Raketenstart schaffen.
14. **Rennhinweise**: "WRONG WAY!"-Warnung, "FINAL LAP!" und Rundenzeit nach jeder Runde.
15. **Codes und Freunde einladen**: Code-Feld in den Einstellungen (FIRE, DRIFTKING, BLASTOFF = Münzen, INFERNO = 1 Inferno-Item; je einmal pro Spieler) und INVITE-Knopf (Roblox-Einladung).

Keine neuen Robux-Produkte.
