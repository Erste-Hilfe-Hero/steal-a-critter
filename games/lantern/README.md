# Lantern Legends – Action-RPG mit Dungeons, Beute und Koop

Ein eigenes Action-RPG im Stil der klassischen Dungeon-Crawler: schräge Draufsicht, Klassen, Monsterwellen, Bosse und Beute in Lichtsäulen. Alles ist selbst gebaut (Monster aus Parts, keine fremden Assets, keine fremden Namen). Cartoon-Fantasy ohne Blut oder Dämonen, passt zu **Mild 9+**.

## Spielablauf

1. In der Stadt **Lanternhold** eine Klasse am Klassenschrein wählen (Knight, Ranger, Mage, ab Stufe 20 Lightbringer).
2. In einen leuchtenden Portalkreis laufen. Wer in 10 Sekunden dazukommt, spielt mit (bis 4 Spieler, auch Fremde = automatisches Koop). Der Erste wählt die Schwierigkeit.
3. Startraum → 4 Kampfräume mit je 2 Wellen → Bossraum. Rote Kreise am Boden = ausweichen.
4. Jeder Spieler bekommt seine eigene Beute (kein Streit). Seltenheit an der Farbe der Lichtsäule: Common, Uncommon, Rare, Epic, Legendary (mit Spezialkraft) und Mythic (nur Nightmare).
5. Truhe am Ende, beim ersten Abschluss zusätzlich Epic. Danach wird der nächste Dungeon bzw. die nächste Schwierigkeit frei.
6. In der Tasche: Bestes anlegen, alte Sachen zu Splittern zerlegen, Auto-Zerlegen. In der **Schmiede** Ausrüstung mit Gold und Splittern bis +10 verbessern.

**6 Dungeons:** Mossy Burrows (Lv 1), Goblin Mines (6), Frostfang Caverns (12), Ember Forge (19), Sunken Temple (27), Starfall Citadel (36), jeweils auf Normal, Hard und Nightmare. 17 Monsterarten, 6 Bosse mit Stampfen, Geschosshagel und Helfern, Wut-Phase ab 50 %.

**Steuerung:** Handy: Joystick + große Knöpfe (Angriff halten, 2 Fähigkeiten, Heiltrank, AUTO). PC: Klick/halten = Angriff, Q/E Fähigkeiten, F Heiltrank, B Tasche, Mausrad Zoom.

## Monetarisierung (eingebaut)

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 299 R$ | +25 % Gold und XP, goldener Name, VIP-Tag |
| Dauerhaft | 2x XP | 249 R$ | doppelte Erfahrung |
| Dauerhaft | Lucky Lantern | 349 R$ | +50 % Chance auf Rare+ (in Ländern mit Lootbox-Regeln ausgeblendet) |
| Dauerhaft | Lantern Sprite | 249 R$ | Licht-Begleiter, der mitkämpft |
| Dauerhaft | Big Backpack | 149 R$ | +100 Taschenplätze |
| Dauerhaft | Lightbringer Class | 199 R$ | Heiler-Klasse sofort (sonst ab Stufe 20) |
| Produkt | Revive | 25 R$ | sofort an Ort und Stelle weiterkämpfen (wird beim Tod angeboten) |
| Produkt | Gold Pouch / Chest / Vault | 49 / 149 / 449 R$ | Gold für ca. 1 / 5 / 20 Läufe (wächst mit der Stufe) |
| Produkt | Shard Bundle | 99 R$ | 400 Schmiede-Splitter |
| Produkt | XP Boost | 79 R$ | 30 min doppelte XP |
| Produkt | Boss Blessing | 149 R$ | nächster Boss: Legendary für die ganze Gruppe (wird allen angesagt; ausgeblendet bei Lootbox-Regeln) |
| Produkt | Starter Pack | 79 R$ | einmalig: Epic-Waffe, 2.500 Gold, 300 Splitter, 30 min 2x XP |
| Werbung | Free Revive / Free Gold | 0 | freiwillige Video-Werbung (Rewarded Ads) |
| Passiv | Premium, Freunde | – | Premium +10 %, jeder Freund im Server +10 % (max. 30 %) |

Angebote erscheinen an passenden Stellen und immer mit „No thanks“: Starter Pack nach 3 Minuten (einmal), VIP/2x XP nach einem Bosssieg, Backpack bei voller Tasche. Für Robux bekommt man nie eine Zufallsbox; alles Zufallsbeeinflussende wird über `PolicyService` ausgeblendet.

## Stil

„Laternenlicht in der Dämmerung“: tiefes Nachtblau und Violett, dazu warmes Bernstein-Licht von Laternen, Glühwürmchen und die Lichtsäulen der Beute. UI: dunkle Panels mit Bernstein-Rand, Titel in Luckiest Guy, Text in Builder Sans. Eigener Ladebildschirm mit schwingender Laterne, Icon und Vorschaubild in `assets/` (`make_art.py`).

## Technik

- `src/server/Services`: `DungeonService` (Lobby, Räume, Wellen, Tod/Revive), `MonsterService` + `MonsterFactory` (KI, Modelle), `CombatService` (Angriffe/Fähigkeiten, serverseitig geprüft), `HeroService` (Werte, XP, Waffe in der Hand), `LootService` (Beute, Tasche, Schmiede), `MonetizationService`, `RewardService` (Tagesbelohnung, Freunde, Bestenliste), `CommunityService` (Ränge wie in den anderen Spielen).
- `src/shared/Items.luau` erzeugt Gegenstände und rechnet Werte (Server und Client nutzen dieselbe Logik).
- `src/client`: `Camera` (Schrägsicht), `Effects` (alle Effekte nur auf dem Client), `UI`.
- Veröffentlichung: `.github/workflows/publish-lantern.yml` sucht die Experience, deren Name „Lantern“ enthält (oder IDs in `roblox.json`), legt die Produkte aus `products.json` an und veröffentlicht. Danach läuft `tests/smoke.luau` im echten Place.

## Update (Oktober 2026): 11 Fehler behoben, 15 neue Features

**Behobene Fehler**

1. Spieler verlässt das Spiel im Dungeon: `Leave` hat noch teleportiert, `LoadCharacter` aufgerufen und Remotes gefeuert. Ein Fehler dabei hätte `DataService:Release` (Speichern!) übersprungen. Jetzt ohne Charakter-Aktionen und jeder Abmelde-Schritt einzeln mit `pcall` geschützt.
2. `SetAutoSalvage` mit NaN wurde gespeichert und hätte jedes weitere Speichern scheitern lassen. Zahlen vom Client werden jetzt auf echte, endliche Werte geprüft (auch `SalvageUpTo`, `SetDifficulty`, Fähigkeiten-Index).
3. `SetDifficulty` mit NaN machte den Lobby-Start kaputt (Gruppe kam nie in den Dungeon).
4. Wiederbeleben (Robux oder Werbung) war nach einem verlorenen Lauf noch möglich und holte den Spieler in einen beendeten Dungeon zurück. Jetzt nur im laufenden Dungeon, sonst Gold als Ersatz.
5. Zusammenfassung meldete „New dungeon unlocked“ und „Hard unlocked“ bei jeder Wiederholung, jetzt nur beim ersten Abschluss.
6. Vote-Kick: der Timer einer abgebrochenen Abstimmung beendete eine neue Abstimmung zu früh.
7. Lantern-Sprite-Schleife ohne `pcall`: ein Fehler hätte den Begleiter für den ganzen Server gestoppt.
8. `Salvage` nahm beliebig lange Id-Listen an (Server-Last), jetzt begrenzt.
9. Meteor und Pfeilregen trafen weiter, nachdem der Spieler den Dungeon verlassen hatte.
10. Volle Gruppe (4/4) am Portal: keine Rückmeldung, jetzt Hinweis.
11. Kleine Handys: das Dungeon-Banner oben in der Mitte überdeckte Gold/Splitter-Anzeige, jetzt rutscht es eine Zeile tiefer. Außerdem heißt die Kraft „Bloodmoon“ jetzt „Lifebloom“ (kein Blut, Mild 9+).

**15 neue Features**

1. **Tägliche Quests** (QUESTS-Knopf): 3 Quests pro Tag aus 10 Arten, Belohnung Gold + Splitter, alle 3 = Bonus-Epic. Abzeichen zeigt abholbare Quests.
2. **Erfolge** (14 Stück, MORE → Achievements) mit Fortschrittsbalken und Gold-Belohnung.
3. **Titel** auf dem Namensschild, durch Erfolge freigeschaltet und auswählbar.
4. **Auren**: leuchtende Kosmetik um den Helden (für Gold, durch Erfolg oder als Robux-Produkt „Royal Aura“ 149 R$).
5. **Codes** (MORE → Codes): LANTERN, LOOT, LIGHTUP, HEROES, je einmal pro Spieler.
6. **Einstellungen** (gespeichert): Soundeffekte, Schadenszahlen, Bildschirmwackeln, automatisch bessere Ausrüstung anlegen.
7. **Trank-Meisterschaft** in der Schmiede: 5 Stufen, mehr Heilung und kürzere Abklingzeit (Gold-Senke).
8. **Dungeon des Tages**: täglich wechselnd +50 % Gold und XP, Schild am Portal, Hinweis in Lobby und Banner.
9. **Kill-Kombo**: Zähler in der Bildmitte, Bonusgold bei 10/25/50/100, beste Kombo wird gespeichert.
10. **Schatz-Kobold**: seltenes Monster, rennt weg und verschwindet nach 20 s; gefangen = viel Gold + garantiert Rare.
11. **Schreine** in Kampfräumen: Kraft (+30 % Schaden), Glück (+50 % Gold) oder Schutz (-40 % Schaden) für die ganze Gruppe.
12. **Versteckte Truhen** in Kampfräumen: jeder Spieler darf einmal öffnen (Gold, oft ein Gegenstand).
13. **Gruppen-Signale** (PING-Knopf im Dungeon): „Help!“, „Attack!“, „Wait!“, „Nice!“ als Sprechblase für die Gruppe.
14. **Heldentagebuch** (MORE → Hero Journal): Lebenszeit-Statistik und persönliche Bestzeiten je Dungeon und Schwierigkeit, „NEW BEST TIME!“ in der Zusammenfassung, Bestzeit in der Lobby.
15. **Einsteiger-Anleitung**: 6 Schritte oben in der Mitte (Klasse, Portal, Boss, Ausrüsten, Schmiede, Quest), jeder mit Goldbelohnung. Bestehende Helden mit abgeschlossenen Läufen überspringen sie.

Neues Produkt in `products.json`: `RoyalAura` (149 R$). Neuer Service: `ProgressService`.

## Offen

- Es gibt noch keine Experience für das Spiel. Per API lässt sich keine anlegen (am 24.10.2026 getestet: alle Endpunkte brauchen ein Login-Cookie). Sobald eine Experience mit „Lantern“ im Namen existiert, veröffentlicht der Workflow automatisch.
- Noch nicht in Roblox Studio gespielt (nur Typprüfung mit luau-lsp und ein Balance-Test der Werte).
