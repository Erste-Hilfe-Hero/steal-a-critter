# surf_ski – Counter-Strike-Surf für Roblox

Nachbau des klassischen **Surf**-Modus aus Counter-Strike 1.6 / Source (benannt nach der Map *surf_ski*), komplett selbst gebaut: eigene Physik, eigene Map aus Code, keine fremden Assets. Mild (9+): keine Gewalt, nur Tempo und Zeiten.

## Was es besonders macht

- **Echte Surf-Physik.** `src/shared/SurfPhysics.luau` rechnet mit den Source-Formeln (Air-Accelerate 150, Air-Cap 30, Gravity 800, ClipVelocity), umgerechnet mit 1 Unit = 1/14 Stud. Die Spielfigur ist eine Box (wie die CS-Hitbox), die per `workspace:Blockcast` gegen die Map gleitet. Steile Flächen (Normal.Y < 0,7) sind Surf-Rampen ohne Reibung, flache Flächen sind Boden.
- **10 Stages im "Alpine Aurora"-Stil**: schneeweiße Dach-Rampen mit Neon-Graten, gefrorener See, Berge, Polarlicht. Jede Stage wird aus Daten erzeugt (`StageLayout.luau`), immer gleich.
- **Timer wie auf CS-Surf-Servern**: Map-Zeit, Stage-Zeit, persönliche Bestzeiten, Welt-Top-10 und Stage-Rekorde (OrderedDataStore), Tacho in u/s.
- **Getestet ohne Roblox**: `tests/run_physics.sh` (16 Physik-Checks) und `tests/run_stages.sh` (ein Bot fährt alle 10 Stages mit der echten Physik durch, ca. 2:34 für die Map). Läuft in jedem Publish-Workflow.
- **Smoke-Test im echten Place** (`tests/smoke.luau`, Workflow `test-surf.yml`): baut die Map, prüft die Rampen mit Strahlen und lässt den Bot mit echtem `Blockcast` fahren.

## Steuerung

| PC | Handy |
|---|---|
| A/D zur Rampe hin halten, Maus lenkt | Stick zur Rampe hin, rechte Seite wischen = lenken |
| Leertaste (halten = Bunny-Hop) | JUMP-Knopf |
| R = Stage neu, 1/2 = Checkpoint, V = Ich-Ansicht, Strg = Mauszeiger | Knöpfe rechts |

Chat: `/r` neuer Lauf, `/s` Stage neu, `/lobby`, `/cp` und `/tele` (Checkpoints).

## Monetarisierung

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 249 R$ | x1,5 Schneeflocken, goldener Name, VIP-Trail und -Skier |
| Dauerhaft | 2x Snowflakes | 199 R$ | doppelte Schneeflocken |
| Dauerhaft | Checkpoints | 149 R$ | Checkpoints speichern/laden (Übungsläufe, zählen nicht für die Bestenliste) |
| Dauerhaft | Trail Pack | 199 R$ | 3 Premium-Trails + Neon-Skier |
| Produkt | Snowflake Bag / Sled / Avalanche | 49 / 199 / 499 R$ | 1.000 / 6.000 / 20.000 Schneeflocken |
| Produkt | Skip Stage | 19 R$ | nächste Stage (Lauf wird "unranked") |
| Produkt | Moon Gravity Party | 99 R$ | 3 Minuten Mondschwerkraft für den ganzen Server (wird angesagt) |
| Produkt | Flake Booster | 49 R$ | 30 Minuten doppelte Schneeflocken (stapelbar, nur Spielzeit zählt) |
| Angebot | Starter Pack | 79 R$ | einmalig: 3.000 Schneeflocken + Ice-Crystal-Trail |
| Werbung | Free Snowflakes | – | freiwillige Video-Werbung (Rewarded Ad), 300 Schneeflocken |
| Passiv | Premium-Bonus | – | x1,2 Schneeflocken |

Schneeflocken gibt es fürs Spielen (Stages, Map, Bestzeit, Spielzeit, 7-Tage-Belohnung) und man kauft damit Trails und Skier. Kein bezahlter Zufall, gekaufte Vorteile verfälschen keine Bestenliste.

## Veröffentlichen

`publish-surf.yml` testet, baut, legt fehlende Produkte an (`products.json`), setzt Name und Beschreibung (`experience.json`) und veröffentlicht in die Experience aus `roblox.json` (Alis Experience "5", Universe 10772779420).

## Update 2 (Oktober 2026)

### Bugfixes

- **Zeit-Schummelei verhindert:** "Startzone verlassen" (`Leave`) nimmt der Server nur noch direkt an der Startzone an. Vorher konnte man die Meldung kurz vor dem Ziel schicken und so Stage- und Map-Zeit verkürzen.
- **Skip Stage verschenkte Robux:** der Skip ging von der aktuellen Stage aus (oft schon freigeschaltet). Jetzt wird immer die nächste gesperrte Stage freigeschaltet; ist schon alles frei und man steht auf der letzten Stage oder in der Lobby, wird gar kein Kauf angeboten.
- **Skier, Trail und Namensschild fehlten manchmal:** `CharacterAppearanceLoaded:Wait()` konnte ewig warten, wenn das Aussehen schon geladen war. Jetzt Abfrage mit Zeitlimit.
- **Tagesbelohnung über Mitternacht:** wer über Mitternacht (UTC) im Spiel blieb, bekam die neue Tagesbelohnung erst nach einem Rejoin.
- **Rang-Ansage wiederholt:** ohne Charakter (z. B. beim Respawn) wurde "ranked up" bei jedem weiteren Abschluss erneut angesagt.
- **ProcessReceipt:** ein Fehler beim Vergeben eines Passes brach die Kaufabwicklung ab; jetzt abgesichert (pcall, NotProcessedYet).
- **Bestenliste sprang zurück:** beim Neuladen aus dem OrderedDataStore (liefert neue Zeiten verzögert) verschwanden frische Bestzeiten und Stage-Rekorde kurz wieder von der Tafel. Jetzt bleiben bessere lokale Werte stehen.
- **Stürze zählten unbegrenzt** (Remote-Spam); jetzt höchstens alle 1,5 s.
- **Anleitung falsch:** "Walk through the DROP IN gate", man startet aber direkt in Stage 1. Text korrigiert.
- **Ergebnis nach der Map** sagte "Press RESTART", obwohl die nächste Runde automatisch startet; der Skip-Preis in der Stage-Auswahl kommt jetzt aus der Config statt fest "19".

### 15 neue Features

1. **Erfolge** (16 Stück, z. B. Speed Demon, Summit Conqueror, Golden Skier) mit Schneeflocken-Belohnung und Popup.
2. **Titel**: jeder Erfolg ist ein Titel für Namensschild und Chat (statt des Rangs).
3. **Tagesaufgaben**: jeden Tag 3 aus 8 Aufgaben (Stages schaffen, Tempo, Medaille, PB ...) mit Fortschrittsbalken und CLAIM.
4. **Profil**: Statistik (Rang mit Abstand zum nächsten, Bestzeit, Höchsttempo, Abschlüsse, Stürze, Spielzeit, Freunde) und Medaillen-Übersicht.
5. **Höchsttempo**: der Server misst das Tempo selbst (Teleports zählen nicht); der Rekord steht unter dem Tacho.
6. **Zwischenzeiten**: im gewerteten Lauf zeigt jede Stage die Differenz zur Zwischenzeit des Bestzeit-Laufs (SPLIT -0.512).
7. **Medaillen** Bronze/Silber/Gold pro Stage (Gold-Zeiten in `Progression.luau`), mit Bonus-Schneeflocken und Anzeige in der Stage-Auswahl.
8. **Einstellungen** (gespeichert): andere Spieler ausblenden, Schneefall, Tacho, Tempo-Effekte, Wind, Tastatur-Hilfe.
9. **Codes**: SURFSUP, SKI2026, AURORA, POWDER (je einmal pro Spieler).
10. **Buddies**: 5 kleine Begleiter aus Teilen an der Schulter (Schneemann, Pinguin, Polarfuchs, Aurora-Orb, Schnee-Eule), neuer Shop-Reiter.
11. **Schneesturm-Event**: alle 20 Minuten 4 Minuten doppelte Schneeflocken für den ganzen Server, mit Countdown, Ansage und dichterem Schnee.
12. **Freundes-Bonus**: +10 % Schneeflocken pro Freund im Server (max. +30 %); Multiplikator-Anzeige neben den Schneeflocken.
13. **Glücks-Schneeball**: einmal pro Tag gratis würfeln (nur Spielwährung, Booster oder die seltene Schnee-Eule).
14. **Tempo-Meilensteine** (1.000 / 2.000 / 3.000 u/s) mit Einblendung, Ton und Geschwindigkeitslinien am Bildrand.
15. **Flake Booster** (neues Produkt, 49 R$): 30 Minuten doppelte Schneeflocken, stapelbar, läuft nur während man spielt.

Alles erreichbar über den neuen Knopf **MORE** (roter Punkt = etwas abzuholen). Neuer Test: `tests/run_progression.sh` (Aufgaben, Medaillen, Glücks-Schneeball).
