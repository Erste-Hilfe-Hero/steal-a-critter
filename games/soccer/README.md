# ⚽ Soccer Jam

Arcade-Fußball wie der alte CS-1.6-Mod "Soccer Jam", nachgebaut für Roblox: alle Original-Mechaniken, großes Stadion, alles per Code gebaut, keine fremden Assets. Messer und Smacks machen Schaden wie im Original, aber cartoonhaft: kein Blut, bei 0 HP ist man K.O. (umgekippt) und steht nach 3 Sekunden an der Startposition wieder auf. Im Roblox-Fragebogen: Gewalt = mild/unrealistisch, kein Blut. "Counter-Strike"/"CS 1.6" steht bewusst nicht im Namen (Marke von Valve).

## Gameplay (wie im Original)

- **Team Red gegen Team Blue**, bis 10 gegen 10 auf einem großen Feld (340 x 200 Studs). Bots füllen jedes Team auf mindestens 4 auf. Kommen echte Spieler dazu, gehen Bots raus. Slot 1 ist der Torwart.
- **Ball annehmen**: hinlaufen, der Ball klebt am Fuß. **Schießen**: Klick/KICK halten lädt die Kraft auf, Zielen mit der Kamera.
- **Curve Ball**: beim Schuss seitlich laufen, der Ball zieht eine Kurve.
- **Smack**: ein harter gegnerischer Schuss haut dich um und macht 20 bis 60 Schaden, wenn deine Dexterity zu niedrig ist. Mit hoher Dexterity fängst du ihn.
- **Messer wie in CS 1.6** (100 HP): **KNIFE** (Klick ohne Ball/F/Q) = Slash 15 Schaden, von hinten 45; ist der Disarm bereit, sprintet man dabei mit Zielhilfe auf den Ballführer zu und nimmt ihm den Ball ab. **STAB** (Rechtsklick/G) = 65 Schaden, Backstab 195 (sofort K.O.). K.O. gibt 100 EXP, nach dem Aufstehen 2 Sekunden Schutz. **Passen** (E/PASS) zum besten Mitspieler in Blickrichtung. **Turbo** (Shift/R/TURBO) mit Ausdauer-Balken.
- **Maskottchen** vor jedem Tor: wer zu lange im gegnerischen Strafraum campt, wird rausgeworfen.
- **Ball-Reset**: liegt der Ball 25 Sekunden unberührt, geht er zurück in die Mitte.
- **Match**: 8 Minuten oder bis ein Team 10 Tore hat, bei Gleichstand **Golden Goal**. Danach Ergebnis mit Auszeichnungen (Top Scorer, Playmaker, Thief, Wall, Smacker, Knockout King).
- **EXP pro Match** wie im Original: Tor 300 (+Bonus für Distanz), Assist 150, Steal 100, Save 150, Smack 80, K.O. 100, Ausweichen 40. Damit kaufst du **5 Upgrades**: Stamina, Strength, Agility, Dexterity, Disarm (je 5 Stufen). Upgrades und EXP werden jedes Match zurückgesetzt.
- Dauerhaft: Account-Level, Coins, Kick-Trails, tägliche Coins mit Serie, Leaderboard.

## HUD und Sounds

- **TV-Anzeige oben rechts** wie beim echten Fußball: RED : BLUE, Spielzeit, Ballbesitz-Balken und Team-Statistik (Ballbesitz, Schüsse, Steals, Saves, Smacks, Knockouts), darunter der Kill-Feed. Antippen klappt die Statistik ein.
- **Sounds** (selbst erzeugt mit `assets/make_sounds.py`): Anpfiff/Abpfiff, Schuss, Tor-Hupe mit Jubel, Publikums-Atmosphäre, "Ooh" bei Smacks, Disarm-Wusch, Countdown-Piepen. `.github/workflows/sounds-soccer.yml` lädt sie als Audio hoch; die IDs kommen nach `src/shared/SoundIds.json`. Solange eine ID 0 ist, spielt ein eingebauter Roblox-Sound.

## Look

Abendstadion mit Flutlicht, Tribünen, Publikum, Banden mit SOCCER-JAM-Slogans, Kraftfeld-Netzen in Teamfarbe, großer Anzeigetafel und Maskottchen. Eigener Ladebildschirm, Icon und Vorschaubild in `assets/` (erzeugt mit `assets/make_art.py`).

## Monetarisierung

| Produkt | Preis | Wirkung |
|---|---|---|
| VIP | 199 R$ | +200 Start-EXP pro Match, x1.5 Coins, goldener Name, Golden-Trail |
| Double XP | 249 R$ | doppelte Match-EXP und Account-XP für immer |
| Double Coins | 199 R$ | doppelte Coins für immer |
| Pro Boots | 299 R$ | +1 auf alle 5 Upgrades in jedem Match, auch über das Maximum |
| Effects Pack | 149 R$ | 3 animierte Trails |
| Coin Pouch / Bag / Chest | 49 / 129 / 349 R$ | 600 / 1.800 / 5.500 Coins |
| +600 Match EXP | 39 R$ | sofort upgraden (dieses Match) |
| Max All Upgrades | 149 R$ | alle Upgrades auf Maximum (dieses Match) |
| XP Boost 30 min | 39 R$ | 2x XP, stapelt mit Double XP |
| Stadium Fireworks | 29 R$ | Feuerwerk für den ganzen Server |
| Starter Pack | 79 R$ | einmalig: 2.500 Coins, 1.000 Match-EXP, Starter-Trail |
| Free Coins | Video-Werbung | Roblox zahlt pro angesehener Werbung |

Im Upgrade-Fenster kann man auch 250 EXP für Coins kaufen. Angebote: Starter Pack nach 90 Sekunden (einmal), XP-Boost nach jeder zweiten Niederlage, Match-EXP wenn EXP fehlt. Keine Lootboxen. Die "Passes" sind Developer Products, die dauerhaft gespeichert werden.

## Update: 15 neue Features und Fehlerbehebungen

Neu (Server `FeaturesService.luau`, Client `Features.luau`, Werte in `Config.luau`). Im Menue links gibt es jetzt drei Spalten mit **SPIN**, **CHAT** und **MORE**:

1. **Erfolge**: 14 Karriere-Ziele (erstes Tor, 100 Tore, 250 K.O.s, 100 Siege, Level 25, 10x MVP ...) mit einmaliger Coin-Belohnung, Fenster mit Fortschritt (MORE > ACHIEVEMENTS).
2. **Wochen-Herausforderung**: eine grosse Aufgabe pro Woche fuer alle (z. B. 10 Tore), 1.200 bis 1.500 Coins, Countdown bis Montag.
3. **Taegliches Gluecksrad** (SPIN): einmal am Tag gratis, weitere Drehungen 300 Coins (nur Spielwaehrung). Preise: Coins, Rocket Shot, 15 Minuten 2x XP. Rotes "!" am Knopf, wenn die Gratis-Drehung bereit ist.
4. **Codes** (MORE > CODES): SOCCERJAM, WELCOME, GOAL, SAMURAI (Coins) und ROCKET (2 Rocket Shots), jeder einmal pro Spieler.
5. **Rang-Punkte**: Sieg +25, Unentschieden +5, Niederlage -15; Raenge Bronze, Silver, Gold, Platinum, Diamond, Champion, Aufstieg wird angesagt.
6. **Match-Verlauf**: die letzten 8 Matches mit Ergebnis, Tore, Vorlagen und K.O.s (MORE > PROFILE & RANK).
7. **Persoenliche Rekorde**: haertester Schuss (km/h), weitestes Tor, meiste Tore und K.O.s in einem Match, mit "NEW RECORD!"-Meldung.
8. **MVP des Matches**: Punkte aus Toren, Vorlagen, Paraden, Steals und K.O.s; steht ganz oben bei den Auszeichnungen, echte Spieler bekommen 150 Coins.
9. **Muenzen auf dem Feld**: alle 20 Sekunden erscheint eine goldene Muenze (20 bis 50 Coins), nur Spieler koennen sie einsammeln.
10. **Power-Orbs**: Speed (+20 % Tempo fuer 8 s), Power (naechster Schuss +40 %) und Heal (volle Leben).
11. **Modus-Abstimmung**: im Ergebnis-Fenster fuer das naechste Match abstimmen: Classic, Low Gravity, Turbo (alle 20 % schneller, auch Bots) oder Mega Kicks (+25 % Schusskraft).
12. **Schnell-Chat** (CHAT oder Taste C): 8 feste Sprueche als Sprechblase ueber dem Kopf, Mitspieler sehen sie auch als Meldung. Keine freie Eingabe.
13. **Freunde-Bonus**: +20 % Coins, solange ein Roblox-Freund auf demselben Server spielt (Anzeige oben links).
14. **Torjubel-Effekte** (MORE > CELEBRATIONS): Confetti, Stars, Flames, Lightning, Galaxy fuer 800 bis 3.500 Coins, platzen beim Tor rund um den Schuetzen.
15. **Anleitung** (MORE > HOW TO PLAY): 5 Seiten Regeln und Steuerung, oeffnet sich beim ersten Besuch automatisch.

Fehler behoben:

- Kick-Remote nahm unendlich lange Richtungsvektoren an, der Ball bekam dann eine NaN-Geschwindigkeit.
- Einstellungen: NaN-Werte vom Client (FOV, Publikum) wurden gespeichert und haetten die Kamera kaputt gemacht.
- Gekaufte Rocket Shots gingen beim Verlassen des Servers verloren (nur Attribut), jetzt gespeichert.
- Wer das Spiel verliess, bevor "sein" Tor zaehlte, wurde wieder in die Match-Statistik eingetragen (Speicherleck, Name in den Auszeichnungen).
- `ArenaService:InGoalZone` griff auf nicht vorhandene Config-Werte zu (toter Code, entfernt).
- Gespeicherte Unter-Tabellen (Einstellungen, Rekorde ...) bekommen neue Schluessel jetzt auch bei alten Spielstaenden.
- Ergebnis-Fenster zeigte die K.O.s nicht, obwohl der Server sie schickt.

## Deploy

`.github/workflows/publish-soccer.yml` läuft bei jedem Push nach `games/soccer/` auf `main`: Experience über den Namen finden (`roblox.json`, sonst Name passt zu "Soccer" oder "7"), Produkte anlegen und ihre IDs in `src/shared/ProductIds.json` schreiben, Name/Beschreibung setzen, mit Rojo bauen, veröffentlichen und Icon/Vorschaubild hochladen. Die Experience ist "7" (Universe 10772779542), fest eingetragen in `roblox.json`.
