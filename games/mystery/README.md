# Midnight Mystery – Krimi-Rundenspiel (Murderer, Sheriff, Innocents)

Ein Rundenspiel im Stil der großen "Wer ist der Mörder?"-Spiele, aber mit eigenem Namen, eigener Mitternachts-Optik, eigenen Waffen-Skins aus Parts und vielen Extras. Altersfreigabe-freundlich (Mild 9+): Treffer sind Cartoon-K.o.s mit Sternchen und Konfetti, kein Blut.

## Spielablauf

1. **Lobby** unter dem Mond: Shop-, Kisten-, Pass- und Inventar-Stände, Bestenlisten (Wins, Knockouts), Obby mit Truhe.
2. **Pause** (20 s) mit Karten-Abstimmung (3 von 5 Karten) und manchmal einem Runden-Modifikator.
3. **Rollen** (geheim): 1 Murderer, 1 Sheriff, der Rest Innocents. Ab 12 Spielern zwei Murderer (Duo). Fehlen Spieler, füllen Bots (als Bot markiert) auf mindestens 5 auf.
4. **Runde** (3 min): Innocents sammeln Münzen und überleben, der Murderer schaltet alle aus (Stich oder Wurf), der Sheriff stoppt ihn mit dem Blaster. Trifft der Sheriff einen Unschuldigen, sind beide raus und der Blaster fällt; ein Innocent kann ihn aufheben und wird **Hero**.
5. **Ergebnis**: Münzen, XP, Battle-Pass-Fortschritt, Quests, Ghost Guess für Ausgeschiedene.

## Die 30 Extras

1. Bots füllen leere Server (sofort spielbar allein)
2. 6 Karten: Manor, Arcade, Lodge, School, Lab, Museum
3. Karten-Abstimmung
4. 6 Runden-Modifikatoren (Blackout, Double Coins, Low Gravity, Speedy, Fog, Gold Rush)
5. Taschenlampen bei Blackout
6. Verstecken in Schränken (Murderer kann durchsuchen)
7. Lüftungsschächte nur für den Murderer
8. Türen zuschlagen
9. Murderer-Fähigkeiten: Dash, Cloak, Glue Trap
10. Sheriff-Fähigkeit: Fußspuren-Scan
11. Sprint mit Ausdauer für Innocents
12. Power-ups: Speed, Shield, Magnet, Ghost
13. Hero-System (Blaster aufheben)
14. Duo-Murderer ab 12 Spielern
15. Ghost Guess: Ausgeschiedene raten den Murderer
16. Zuschauen (Spectate) mit Durchschalten
17. 18 Messer, 12 Blaster, 9 Haustiere, 7 K.o.-Effekte
18. 4 Kisten mit offen angezeigten Quoten
19. Forge: 5 Duplikate einer Seltenheit zu einem frei wählbaren Skin der nächsten schmieden
20. Battle Pass mit 30 Stufen (Free und Premium)
21. Tägliche Quests
22. Erfolge mit freischaltbaren Titeln
23. Level und Prestige
24. Tägliche Belohnung (Streak)
25. Glücksrad mit angezeigten Chancen
26. Emotes
27. Codes (MIDNIGHT, MYSTERY, BIGBABA, SLEUTH)
28. Lobby-Obby mit Truhe
29. Rollen-Tickets (höhere Chance auf Murderer/Sheriff)
30. Freunde-Bonus (+10 % Münzen pro Freund), Tutorial beim ersten Start, eigener Ladebildschirm

## Monetarisierung

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 299 R$ | x1,5 Münzen, +10 Beutel, VIP-Tag, goldener Name |
| Dauerhaft | 2x Coins / 2x XP | 249 / 199 R$ | doppelte Münzen bzw. XP |
| Dauerhaft | Big Bag | 149 R$ | +20 Münzen-Beutel |
| Dauerhaft | Emote Pack / Pet Slot | 99 / 149 R$ | Extra-Emotes, zweites Haustier |
| Produkt | Coins (4 Pakete) | 49 / 149 / 399 / 999 R$ | Münzen |
| Produkt | Murderer / Sheriff Ticket | 49 / 39 R$ | nächste Runde diese Rolle (wenn möglich) |
| Produkt | Premium Pass S1 | 399 R$ | Premium-Spur im Battle Pass |
| Produkt | Tier Skip 1 / 10 | 49 / 349 R$ | Pass-Stufen überspringen |
| Produkt | Starter Pack (einmalig) | 79 R$ | Münzen + Skin |
| Produkt | Moon / Star Bundle | 499 / 199 R$ | exklusive Midnight-Skins + Münzen |
| Produkt | 2x XP 30 min / Server Blackout | 39 / 29 R$ | Booster bzw. Blackout-Modifikator für die nächste Runde |
| Produkt | Midnight Hour | 49 R$ | 10 Minuten doppelte Münzen und 1,5x XP für den ganzen Server |
| Werbung | Free Coins (Video) | – | Münzen pro freiwilliger Werbung (alle 5 min) |

Kisten kosten nur Münzen (keine Robux), Quoten stehen in der Kiste und im Glücksrad. Ist Zufalls-Kauf per `PolicyService` nicht erlaubt, werden Kisten ausgeblendet und Skins nur direkt verkauft.

## Technik

- `src/server/Services`: `RoundService` (Ablauf, Rollen, Sieg, Midnight Hour, Glücksbringer), `ClueService` (Hinweise), `CombatService` (Messer, Wurf, Blaster, Hero), `BotService` (Pathfinding-Bots), `MapService`/`MapBuilder` (Karten, Lobby, Schränke, Türen, Schächte), `CoinService`, `AbilityService`, `ProgressService` (Level, Pass, Quests, Erfolge), `InventoryService` (Kisten, Forge), `MonetizationService`, `DataService`.
- `src/client`: `UI` (gesamte Oberfläche), `Controls` (Eingabe, Handy-Knöpfe), `Effects`; Ladebildschirm in `src/first`.
- Bilder: `tools/art/scenes/mystery.py` (Blender) erzeugt `assets/icon.png` und `assets/thumbnail.png`.
- Experience: wird von `.github/workflows/create-experiences.yml` angelegt (Eintrag in `experiences.json`).
- Veröffentlichen: `.github/workflows/publish-mystery.yml` findet die Experience über den Namen, legt die Produkte an, lädt eine Saved-Version hoch, lässt `tests/smoke.luau` auf Roblox laufen (alle Karten bauen, drei Bot-Runden inkl. Verstecken, Schacht, Hero) und schaltet erst bei 0 Fehlern live.

## Update (Bugfixes + 15 neue Punkte)

### Behobene Fehler

1. Ghost Guess im Duo-Modus: nur der zuletzt gefundene Murderer zählte, ein richtiger Tipp auf den anderen gab nichts.
2. Shadow + Ghost-Power-Up gleichzeitig: der Murderer blieb danach für immer unsichtbar (zweiter Effekt speicherte die schon durchsichtigen Werte).
3. K.O.-te Spieler konnten noch fast 1 s weiterlaufen, weil die Sprint-Steuerung des Clients das Tempo sofort zurücksetzte.
4. Wurf/Schuss: Zielpunkte vom Client wurden nicht auf NaN/unendlich geprüft.
5. Kisten-Animation wurde sofort gelöscht (Münz-Update baute das Fenster neu); ebenso schloss sich die Schmiede und ein getippter Code verschwand.
6. HUD fror komplett ein, wenn man einem gerade zerstörten Bot zuschaute (Fehler in der Aktualisierungs-Schleife).
7. Ghost-Guess-Knopf kam für Lobby-/AFK-Zuschauer nach dem ersten Tipp nie wieder.
8. Duo-Modus: ein zweiter fallengelassener Blaster löschte den ersten.
9. Wer am Rundenende im Schrank versteckt war, wurde nach dem Lobby-Teleport zurück auf die gelöschte Karte gesetzt und fiel ins Leere.
10. Handy-Sprint blieb nach der Runde in der Lobby dauerhaft an (ohne Ausdauerverbrauch).
11. Handy-Layout: die linke Menüspalte überlappte Münzanzeige und FREE-COINS-Knopf (jetzt 2-spaltiges Raster).
12. Speicherlecks: Abklingzeiten K.O.-ter Teilnehmer/Bots, doppelte Schild-Verbindungen pro Runde, Freundeszähler für gegangene Spieler.
13. Bestenlisten fragten alle 2 Minuten jeden Namen neu ab (jetzt Zwischenspeicher); README nannte falsche Bestenliste (Level statt Knockouts).
14. Quest-Abzeichen im Menü konnte nie erscheinen (Quests werden sofort belohnt) – erscheint jetzt bei erledigter Quest.

### 15 neue Punkte

1. **Hinweise (Clues)**: Lupen auf der Karte verraten Namenslänge, Entfernung und Anfangsbuchstaben des Murderers (+15 Münzen, nicht für den Murderer).
2. **Letzter Überlebender**: Ansage, Tempo-Bonus und +25 Münzen, wenn er durchhält; eigene Zeile im Ergebnis.
3. **Siegesserie**: Bonus-Münzen pro Sieg in Folge (bis +50), Anzeige im Ergebnis, in den Stats und in der Spielerliste.
4. **Wöchentliche Quests**: 3 große Quests pro Woche mit hohen Belohnungen und Battle-Pass-XP (neuer Tab).
5. **Midnight Hour**: zur vollen/halben Stunde 5 Minuten 2x Münzen und 1,5x XP für alle, Countdown-Chip im HUD; als Produkt für 10 Minuten startbar.
6. **Neue Karte Midnight Museum** (Galerie, Dino-Fossil, Edelstein-Vitrinen, Statuenhalle).
7. **Zwei neue Modifikatoren**: Super Jump und Lucky Boxes (dreimal so viele Power-Ups).
8. **Mystery Box**: gemischte Kiste mit allen Arten, Quoten sichtbar, nur Münzen.
9. **Neue Skins**: 3 Messer, 2 Blaster, 2 Haustiere, 2 K.O.-Effekte (Snowflakes, Rainbow).
10. **7 neue Erfolge mit Titeln** (Investigator, Unstoppable, Lone Wolf, Psychic, MVP, Unboxer, Prestige).
11. **MVP-Bonus**: +15 Münzen und MVP-Zähler für den besten Spieler der Runde.
12. **Einstellungen** (gespeichert): Soundeffekte, Haustiere anzeigen, Zielhilfe.
13. **Spielerliste**: wer ist im Server, mit Level, Prestige, Titel, Siegen und Serie (die Roblox-Liste ist wegen geheimer Rollen aus).
14. **Zielhilfe auf Handys**: Blaster und Messerwurf zielen auf die nächste sichtbare Figur nahe der Bildschirmmitte (nie auf Unsichtbare/Versteckte).
15. **Glücksbringer**: mit Münzen die Chance auf Murderer oder Sheriff erhöhen, bis man die Rolle bekommt (Anzeige im Chancen-Chip).
