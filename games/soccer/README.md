# ⚽ Turbo Soccer

Schnelles Arcade-Fußballspiel im Stil des alten CS-1.6-Mods "Soccer Jam", aber komplett eigen: eigener Name, eigener Look, alles per Code gebaut, keine fremden Assets. Altersfreigabe-tauglich für Mild (9+): Tacklings nehmen nur den Ball ab, niemand wird verletzt.

## Gameplay

- **Team Bolt (Cyan) gegen Team Blaze (Orange)**, bis 8 gegen 8. Bots füllen jedes Team auf mindestens 3 auf, damit man auch allein sofort spielen kann. Kommen echte Spieler dazu, gehen Bots raus.
- **Ball annehmen**: einfach hinlaufen, der Ball klebt am Fuß. Zu schnelle Schüsse prallen ab (Block). Mit hoher Dexterity fängt man auch harte Schüsse.
- **Schießen**: Klick/SHOOT halten lädt die Schusskraft auf, Zielen mit der Kamera. **Passen** (E/PASS) spielt automatisch zum besten Mitspieler in Blickrichtung.
- **Tackling** (F, Klick ohne Ball oder TACKLE): kurzer Sprint nach vorne, nimmt dem Gegner den Ball ab. Wer ausweicht, bekommt XP.
- **Sprint** mit Ausdauer-Balken (Shift/SPRINT).
- **Match**: 4 Minuten, Anstoß nach jedem Tor, bei Gleichstand **Golden Goal**. Danach Ergebnis-Fenster mit Toren, Assists, Tacklings, Saves, XP und Coins.
- **5 Skills wie im Original**: Stamina, Strength, Agility, Dexterity, Tackle (je 10 Stufen). Jedes Level gibt 1 Skillpunkt. Extra-Punkte gibt es für Coins (Preis steigt) oder Robux.
- **Kick-Trails**: Farbspur hinter deinen Schüssen, 7 für Coins, dazu VIP-, Starter- und Effects-Pack-Trails. Tor-Explosion in deiner Trail-Farbe.
- Tägliche Coins mit Serie (bis 750 Coins am 7. Tag), Leaderboard mit Level und Toren.

## Look

Eigener "Turbo"-Stil: Navy mit Lime und Orange, dicke Schrift (Luckiest Guy), Flutlicht-Stadion am Abend mit Tribünen, Publikum, Banden mit Slogans, Kraftfeld-Netzen in Teamfarbe und großer Anzeigetafel. Eigener Ladebildschirm mit springendem Ball, Icon und Vorschaubild in `assets/` (erzeugt mit `assets/make_art.py`).

## Monetarisierung

| Produkt | Preis | Wirkung |
|---|---|---|
| VIP | 199 R$ | x1.5 Coins, goldener Name, VIP-Chat-Tag, Golden-VIP-Trail |
| Double XP | 249 R$ | doppelte XP für immer |
| Double Coins | 199 R$ | doppelte Coins für immer |
| Pro Boots | 299 R$ | +1 auf alle 5 Skills, auch über das Maximum |
| Effects Pack | 149 R$ | 3 animierte Trails |
| Coin Pouch / Bag / Chest | 49 / 129 / 349 R$ | 600 / 1.800 / 5.500 Coins |
| +3 Skill Points | 59 R$ | sofort upgraden |
| Skill Reset | 25 R$ | alle Punkte zurück |
| XP Boost 30 min | 39 R$ | 2x XP, stapelt mit Double XP |
| Stadium Fireworks | 29 R$ | Feuerwerk für den ganzen Server |
| Starter Pack | 79 R$ | einmalig: 2.500 Coins, 5 Skillpunkte, Turbo-Trail |
| Free Coins | Video-Werbung | Roblox zahlt pro angesehener Werbung |

Angebote im Spiel: Starter Pack nach 90 Sekunden (einmal, mit "No thanks"), XP-Boost nach jeder zweiten Niederlage, +3 Skillpunkte wenn man ohne Punkte upgraden will, Coin-Shop wenn Coins fehlen. Der Free-Coins-Button erscheint nur, wenn Roblox wirklich eine Werbung hat. Nichts im Spiel ist zufällig (keine Lootboxen).

Die "Passes" sind Developer Products, die dauerhaft gespeichert werden, weil der API-Schlüssel keine echten Gamepasses anlegen kann.

## Deploy

`.github/workflows/publish-soccer.yml` läuft bei jedem Push nach `games/soccer/` auf `main`: Experience über den Namen finden (enthält "Soccer"), Produkte anlegen und ihre IDs in `src/shared/ProductIds.json` schreiben, Name/Beschreibung setzen, mit Rojo bauen, veröffentlichen und Icon/Vorschaubild hochladen. Solange es keine Experience mit "Soccer" im Namen gibt, wird nur gebaut. Sobald sie gefunden wurde, die IDs in `roblox.json` eintragen.
