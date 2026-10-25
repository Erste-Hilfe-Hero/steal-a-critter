# Mega Rainbow Obby

Ein Obby mit **100 Stages in 10 Welten** (Candy Land, Jungle, Desert, Ice Peaks, Lava Lair, Ocean, Neon City, Cloud Kingdom, Outer Space, Rainbow Road). Alles wird per Code gebaut, ohne fremde Assets.

## Warum ein Obby?

- Obbys sind das Genre mit den meisten Besuchen bei kleinen Spielen: einfach zu verstehen, laufen gut auf dem Handy und sind ideal für jüngere Spieler.
- Das meiste Geld bringt der **Skip-Stage-Kauf**. Wer festhängt, zahlt kleine Beträge oft. Deshalb ist der Skip-Button groß und leuchtet auf, wenn jemand mehrmals an derselben Stage stirbt.
- Dazu kommen dauerhafte Vorteile wie Coils, Double Jump, VIP und Trails sowie ein Troll-Kauf ("Kill Everyone"), den viele kaufen und der vom ganzen Server gesehen wird.

## Gameplay

- Checkpoint auf jeder Stage, wird gespeichert. Nach dem Tod erscheint man am letzten Checkpoint.
- Hindernisse: Sprünge, Lava-Streifen, Leitern mit Kill-Balken, drehende Balken, verschwindende Plattformen, Seiltanz, Treppen, Zickzack, fahrende Kill-Wände, Säulen und rollende Kugeln. Die Schwierigkeit steigt über alle 100 Stages.
- Ziel nach Stage 100 = **+1 Win**, dann geht es von vorne los. Wins und Stage stehen im Leaderboard.
- **Trails**: 7 kostenlose durch Fortschritt (Stage 10/25/50/75, 1 und 5 Wins), 1 VIP-Trail, 6 im Trail Pack.
- **Namensschilder** über dem Kopf: Rang, Name (VIP in Gold mit Krone, Owner mit Regenbogen), Stage, Welt und Wins.
- **Community-Ränge** wie in Steal a Critter (Newbie → Member → Regular → Veteran → Guardian, Owner). Befehle: /rank /yes /votekick /announce /kick /ban /unban /revoke /restore.

## Monetarisierung

| Produkt | Preis | Wirkung |
|---|---|---|
| VIP | 199 R$ | Goldener Name, [VIP]-Chat-Tag, Golden-VIP-Trail |
| Double Jump | 199 R$ | in der Luft noch einmal springen |
| Gravity Coil | 149 R$ | Tool: viel höher springen |
| Speed Coil | 99 R$ | Tool: schneller rennen |
| Trail Pack | 149 R$ | 6 Premium-Trails |
| Skip Stage | 19 R$ | nächste Stage |
| Skip 5 / Skip 10 | 79 / 129 R$ | 5 bzw. 10 Stages weiter |
| Kill Everyone | 49 R$ | alle anderen erscheinen an ihrem Checkpoint neu |

Die "Passes" sind Developer Products, die dauerhaft gespeichert werden, weil der API-Schlüssel keine echten Gamepasses anlegen kann. Der Workflow legt die Produkte automatisch an, und das Spiel findet ihre IDs selbst über den Namen.

## Deploy

`.github/workflows/publish-obby.yml` baut bei jedem Push nach `games/obby/` die Place-Datei mit Rojo. Die Experience wird über den API-Schlüssel gesucht (Name enthält "Obby"). Danach setzt der Workflow Name und Beschreibung, legt die Produkte an und veröffentlicht.

## Update: Fehlerbehebungen und 15 neue Features

### Behobene Fehler

- **Lava-Stages (ab ca. Stage 80) fast unschaffbar**: Zwischen den Lava-Streifen blieben nur ca. 2,4 Studs; ein normaler voller Sprung landete im nächsten Streifen. Jetzt höchstens 5 schmalere Streifen, mindestens 4 Studs Landefläche.
- **Leitern (Truss) zu kurz**: TrussParts gibt es nur in 2-Stud-Schritten, krumme Höhen wurden gekürzt und die Leiter endete unter der Plattform. Höhe wird jetzt gerade gerundet.
- **Double Jump sofort verbraucht**: JumpRequest feuert beim Drücken mehrmals, der zweite Sprung ging direkt beim Absprung verloren. Jetzt zählt er erst 0,2 s nach dem Absprung.
- **Checkpoint-Cheat**: Wer sich per Exploit zu einem beliebigen Checkpoint teleportierte, bekam diese Stage (bis Stage 100 → Sieg). Jetzt höchstens 3 Checkpoints auf einmal.
- **Skip-Kauf während eines Sieges ging verloren**: Wird jetzt nicht vergeben (NotProcessedYet), Roblox versucht es danach erneut.
- **Votekick-Timer**: Verließ das Ziel einer Abstimmung den Server und startete jemand eine neue, beendete der alte Timer die neue Abstimmung zu früh.
- Typfehler in der Spielersuche (`/kick`, `/votekick` ...) behoben.

### 15 neue Features

1. **Coins** 🪙: für jeden neuen Checkpoint (4 + Weltnummer), 300 pro Sieg; Anzeige oben rechts. VIP bekommt +50 %.
2. **Tägliche Belohnung mit Streak**: 7-Tage-Zyklus (50 … 400 Coins), Popup beim Betreten.
3. **Tägliche Quests**: 3 Quests pro Tag (Checkpoints, Spielzeit, neue Welten) mit Coin-Belohnung, roter Punkt am Quest-Knopf.
4. **Erfolge & Titel**: 12 Erfolge (z. B. Halfway Hero, Champion, Gem Hunter, Speedster), jeder gibt Coins und einen Titel fürs Namensschild.
5. **Coin-Trails**: 4 neue Trails (Bubblegum, Sunset, Aurora, Diamond) für 500–4.000 Coins.
6. **Speedrun-Timer**: läuft ab Stage 1 bis zum Ziel (ohne Skips/Stage-Auswahl), persönliche Bestzeit wird gespeichert und angesagt.
7. **Globale Bestenlisten** in der Lobby: meiste Siege und schnellste Läufe (OrderedDataStore).
8. **Einstellungen**: Soundeffekte, Timer, andere Spieler ausblenden, Tages-Popup (gespeichert).
9. **Codes**: RAINBOW (100), OBBY (50), 100STAGES (150) – je einmal pro Spieler.
10. **Stage-Auswahl**: ◀/▶ an der Stage-Karte, zurück zu jeder erreichten Stage (Coins dann nur für neue Rekorde bis zum nächsten Sieg, kein Farmen).
11. **Emotes**: Wave, Cheer, Point, Laugh, 3 Tänze per Knopf (R15).
12. **Neues Hindernis: Sprungpads** – grüne Pads schleudern einen 16 Studs hoch, jede Stufe 9 Studs höher.
13. **Regenbogen-Edelsteine**: einer pro Welt auf einer kleinen Insel neben Checkpoint x6, je 150 Coins.
14. **Statistik**: Siege, beste Stage, Bestzeit, Respawns, aktive Spielzeit, Edelsteine, verdiente Coins, Streak.
15. **Coin Pack** (neues Developer Product, 49 R$): 1.000 Coins.

Neue Menüknöpfe links (2 Spalten, damit der Steuer-Stick auf dem Handy frei bleibt): Shop, Trails, Quests, Titles, More (Einstellungen, Codes, Emotes, Statistik).
