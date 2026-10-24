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
