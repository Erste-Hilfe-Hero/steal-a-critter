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
| Angebot | Starter Pack | 79 R$ | einmalig: 3.000 Schneeflocken + Ice-Crystal-Trail |
| Werbung | Free Snowflakes | – | freiwillige Video-Werbung (Rewarded Ad), 300 Schneeflocken |
| Passiv | Premium-Bonus | – | x1,2 Schneeflocken |

Schneeflocken gibt es fürs Spielen (Stages, Map, Bestzeit, Spielzeit, 7-Tage-Belohnung) und man kauft damit Trails und Skier. Kein bezahlter Zufall, gekaufte Vorteile verfälschen keine Bestenliste.

## Veröffentlichen

`publish-surf.yml` testet, baut, legt fehlende Produkte an (`products.json`), setzt Name und Beschreibung (`experience.json`) und veröffentlicht in die Experience aus `roblox.json` (Alis Experience "5", Universe 10772779420).
