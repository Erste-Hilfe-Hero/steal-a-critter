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
