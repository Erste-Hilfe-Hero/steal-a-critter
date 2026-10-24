# Midnight Mystery – Krimi-Rundenspiel (Murderer, Sheriff, Innocents)

Ein Rundenspiel im Stil der großen "Wer ist der Mörder?"-Spiele, aber mit eigenem Namen, eigener Mitternachts-Optik, eigenen Waffen-Skins aus Parts und vielen Extras. Altersfreigabe-freundlich (Mild 9+): Treffer sind Cartoon-K.o.s mit Sternchen und Konfetti, kein Blut.

## Spielablauf

1. **Lobby** unter dem Mond: Shop-, Kisten-, Pass- und Quest-Stände, Bestenlisten (Wins, Level), Obby mit Truhe.
2. **Pause** (20 s) mit Karten-Abstimmung (3 von 5 Karten) und manchmal einem Runden-Modifikator.
3. **Rollen** (geheim): 1 Murderer, 1 Sheriff, der Rest Innocents. Ab 12 Spielern zwei Murderer (Duo). Fehlen Spieler, füllen Bots (als Bot markiert) auf mindestens 5 auf.
4. **Runde** (3 min): Innocents sammeln Münzen und überleben, der Murderer schaltet alle aus (Stich oder Wurf), der Sheriff stoppt ihn mit dem Blaster. Trifft der Sheriff einen Unschuldigen, sind beide raus und der Blaster fällt; ein Innocent kann ihn aufheben und wird **Hero**.
5. **Ergebnis**: Münzen, XP, Battle-Pass-Fortschritt, Quests, Ghost Guess für Ausgeschiedene.

## Die 30 Extras

1. Bots füllen leere Server (sofort spielbar allein)
2. 5 Karten: Manor, Arcade, Lodge, School, Lab
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
| Werbung | Free Coins (Video) | – | Münzen pro freiwilliger Werbung (alle 5 min) |

Kisten kosten nur Münzen (keine Robux), Quoten stehen in der Kiste und im Glücksrad. Ist Zufalls-Kauf per `PolicyService` nicht erlaubt, werden Kisten ausgeblendet und Skins nur direkt verkauft.

## Technik

- `src/server/Services`: `RoundService` (Ablauf, Rollen, Sieg), `CombatService` (Messer, Wurf, Blaster, Hero), `BotService` (Pathfinding-Bots), `MapService`/`MapBuilder` (Karten, Lobby, Schränke, Türen, Schächte), `CoinService`, `AbilityService`, `ProgressService` (Level, Pass, Quests, Erfolge), `InventoryService` (Kisten, Forge), `MonetizationService`, `DataService`.
- `src/client`: `UI` (gesamte Oberfläche), `Controls` (Eingabe, Handy-Knöpfe), `Effects`; Ladebildschirm in `src/first`.
- Bilder: `tools/art/scenes/mystery.py` (Blender) erzeugt `assets/icon.png` und `assets/thumbnail.png`.
- Experience: wird von `.github/workflows/create-experiences.yml` angelegt (Eintrag in `experiences.json`).
- Veröffentlichen: `.github/workflows/publish-mystery.yml` findet die Experience über den Namen, legt die Produkte an, lädt eine Saved-Version hoch, lässt `tests/smoke.luau` auf Roblox laufen (alle Karten bauen, drei Bot-Runden inkl. Verstecken, Schacht, Hero) und schaltet erst bei 0 Fehlern live.
