# Steal a Critter – Roblox-Spiel mit Fokus auf Einnahmen

Ein spielbares Grundgerüst im Genre **"Steal a ..."** (Vorbild: *Steal a Brainrot*, 2026 einer der umsatzstärksten Titel und Nummer 1 auf Mobile). Alles ist selbst gebaut: eigene Kreaturen aus Parts, kein fremder Code, keine fremden Assets.

## Warum dieses Konzept?

- **Umsatz kommt aus Besuchen.** Pro Besuch verdienen alle Genres fast gleich viel, etwa 0,008 $. Wer gewinnt, entscheidet sich also über Reichweite und darüber, wie lange Spieler bleiben. "Steal a ..."-Spiele sind extrem viral (Klauen erzeugt Drama, Clips und Rache) und laufen sehr gut auf Mobile, wo die meisten jungen Spieler sind.
- **Wenig Aufwand.** Ein Laufband, Basen und ein Einkommens-Loop. Man braucht keine Kampfsysteme, Level oder Story.
- **Viele Gründe zu zahlen.** Angst vor Diebstahl (Sperre), Gier (Sofortkauf seltener Tiere), Status (VIP) und Ungeduld (Cash-Pakete), alles in einer Schleife.
- **Regelkonform.** Es gibt keine bezahlten Zufallsitems: Der Spieler sieht immer genau, was er kauft. Damit fällt das Spiel nicht unter die Lootbox-Regeln.

## Gameplay-Loop

1. Kreaturen laufen auf dem Laufband vorbei, mit Seltenheit von Common bis Mythic → **[E] kaufen** mit Cash.
2. Kreaturen stehen in deiner Basis und bringen **Einkommen pro Sekunde**.
3. **Bei anderen klauen:** [E] gedrückt halten, dann mit der Kreatur über dem Kopf in die eigene Basis rennen.
4. **Verteidigen:** Diebe mit dem Slap-Tool schlagen, dann fällt die Beute zurück. Oder die Basis sperren (45 s gratis, danach 30 s Abklingzeit).
5. **Rebirth:** Cash und Kreaturen zurücksetzen und dafür dauerhaft +0,5x Einkommen bekommen.

## Was das Spiel im Genre einzigartig macht

Die Features antworten direkt auf die häufigsten Spieler-Beschwerden über "Steal a Brainrot" (Verlust wertvoller Figuren, Griefing, Pay-to-win) und auf das, was dort am meisten Spieler bringt (Events).

- **Diebstahl-Versicherung:** Wer bestohlen wird, bekommt sofort 25 % des Werts zurück.
- **Rache:** 90 s lang kommt das Opfer durch die Sperre des Diebes und klaut mit 0,5 s Haltezeit zurück.
- **Kreaturen-Fusion:** 3 gleiche Kreaturen in der Basis werden mit [F] zu einer Stufe ★ fusioniert (x3,5 Einkommen, bis ★★★).
- **Mutationen:** Golden (x2), Diamond (x4), Rainbow (x10, Farbe läuft durch) auf dem Laufband.
- **Gratis-Server-Events** alle 8 Minuten für 2 Minuten: Golden Hour, Critter Rush, Lucky Belt, Double Cash.
- **Tägliche Belohnung** mit Serie (bis +300 % am 7. Tag).

## Monetarisierung (eingebaut)

| Typ | Produkt | Preisvorschlag | Wirkung |
|---|---|---|---|
| Gamepass | VIP | 249 R$ | x1,5 Einkommen + [VIP]-Tag im Chat |
| Gamepass | 2x Cash | 399 R$ | doppeltes Einkommen |
| Gamepass | +4 Base Slots | 299 R$ | 12 statt 8 Plätze (gesperrte Plätze sind in der Basis sichtbar = Werbung) |
| Gamepass | Fast Steal | 199 R$ | 1 s statt 2,5 s Klauen |
| Gamepass | Speed Coil | 149 R$ | schneller rennen |
| Dev Product | Cash Bag / Crate / Vault | 49 / 199 / 699 R$ | 10 min / 1 h / 6 h Einkommen (wächst mit dem Spieler mit) |
| Dev Product | 5 Min Base Lock | 39 R$ | Schutz vor Dieben |
| Dev Product | Server Luck x3 | 199 R$ | 15 min lang 3x mehr seltene Spawns **für alle** (wird groß angesagt = Social Proof) |
| Dev Product | Instant Epic / Legendary / Mythic | 49 / 149 / 399 R$ | [F] am Laufband: genau diese Kreatur sofort kaufen |
| Passiv | Premium-Bonus | – | Premium-Spieler bekommen x1,2 → mehr Spielzeit → höhere **Premium Payouts** |

Kaufabwicklung: `ProcessReceipt` mit Kaufhistorie gegen doppelte Vergabe und sofortigem Speichern. Gekauft ist immer geliefert: Wenn die Basis voll ist, gibt es Cash statt der Kreatur.

## Projektstruktur (Rojo)

```
default.project.json
src/shared/Config.luau          ← alle Zahlen, Kreaturen, Preise, Produkt-IDs
src/shared/Format.luau
src/server/init.server.luau     ← Startpunkt
src/server/Services/
  DataService.luau              ← Speichern (DataStore, Autosave, BindToClose)
  WorldService.luau             ← baut Map, Laufband und eine Basis pro Spieler (8–24) per Code
  PlotService.luau              ← Basis-Zuweisung, Sperre
  UnitService.luau              ← Laufband, Kaufen, Einkommen, Klauen, Slap, Rebirth
  UnitFactory.luau              ← Kreaturen-Modelle
  MonetizationService.luau      ← Gamepasses, Dev Products, Premium, Server Luck
src/client/init.client.luau     ← Prompts, VIP-Chat-Tag
src/client/UI.luau              ← HUD, Shop, Rebirth-Fenster, Meldungen
```

## Einrichten (ca. 15 Minuten)

1. **Roblox Studio** und **Rojo** installieren (Studio-Plugin + CLI: <https://rojo.space>).
2. In diesem Ordner `rojo serve` ausführen. Dann in Studio einen leeren **Baseplate**-Place öffnen, im Rojo-Plugin auf **Connect** klicken und die Baseplate löschen (die Map wird per Code gebaut).
3. **Testen:** Play drücken. Alle Shop-Käufe werden in Studio simuliert, solange die IDs 0 sind. Zum Klauen: *Test → Clients and Servers → 2 Players → Start*.
4. **Veröffentlichen:** *File → Publish to Roblox*. Dann unter *Game Settings → Security* **"Enable Studio Access to API Services"** einschalten (zum Speichern) (die Anzahl der Basen passt sich automatisch an Max Players an, bis 24).
5. **Produkte anlegen:** Im Creator Hub unter *Monetization → Passes* und *Developer Products* jeden Eintrag aus `Config.luau` anlegen, ein Icon hochladen und den Preis setzen. Dann die IDs in `Config.GamePasses` / `Config.DevProducts` eintragen.
6. Unter *Monetization* **Private Servers** aktivieren (z. B. 100 R$/Monat) für zusätzliche passive Einnahmen.

## So kommt das Geld tatsächlich rein

- **Thumbnail und Icon sind alles.** Die Klickrate entscheidet, ob der Algorithmus das Spiel zeigt. Mehrere Varianten testen (Creator Hub → Thumbnail-Tests).
- **Werbung:** Mit 5.000–20.000 Robux an *Sponsored Experiences / Ads Manager* testen. Wenn Spieler im Schnitt über 10 Minuten bleiben, lohnt es sich, mehr zu investieren.
- **TikTok/Shorts:** Klau-Momente und "Mythic gezogen"-Clips. Das Genre lebt von Clips.
- **Updates jede Woche:** Neue Kreaturen in `Config.Units` eintragen (eine Zeile pro Kreatur) und Events mit Server Luck. Top-Spiele verdienen durch ständige Updates.
- **Live-Daten ansehen:** Creator Hub → *Analytics → Monetization*. Preise anpassen, Einsteiger-Angebote testen.

**Ehrliche Erwartung:** Die meisten Spiele verdienen fast nichts. Die Top 10 teilen sich den Großteil des Umsatzes. Von 1.000 R$ Umsatz bekommst du 700 R$, und DevEx zahlt etwa 0,0038 $ pro Robux, also ca. 2,66 $. DevEx gibt es ab 30.000 R$, ab 13 Jahren und mit verifizierter ID. Den Unterschied machen Marketing und schnelle Updates.

## Nächste Ausbaustufen (größter Hebel zuerst)

1. **Optik:** Bessere Kreaturen-Modelle (eigene Meshes), Sounds, Partikel beim Kaufen und Klauen. Die Namen der Kreaturen können bleiben.
2. **Gruppen-Bonus** (Spieler der Gruppe beitreten lassen = kostenlose Push-Benachrichtigungen durch Updates).
3. **Index/Sammelbuch** aller Kreaturen. Sammeltrieb erhöht die Spielzeit.
4. **Offline-Einkommen** (gedeckelt), damit Spieler zurückkommen.
5. **ProfileStore** statt eigenem DataService, sobald das Spiel wächst (verhindert Datenverlust beim Serverwechsel).

## Regeln, die man einhalten muss

- Keine bezahlten Zufallsboxen ohne Wahrscheinlichkeitsanzeige (hier gibt es keine).
- Keine fremden Marken oder Figuren (deshalb eigene Kreaturen statt "Brainrot"-Charakteren).
- Den Fragebogen zur **Experience Guidelines / Content Maturity** im Creator Hub ausfüllen, sonst wird das Spiel eingeschränkt.

Quellen: [RoWatcher – Highest-Earning Roblox Games 2026](https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform), [profitable.app – Roblox Genres](https://profitable.app/roblox/genres)
