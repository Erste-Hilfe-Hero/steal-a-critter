# Critter Hatch Simulator – Pet-Simulator mit Fokus auf Einnahmen

Ein spielbares Pet-Simulator-Spiel nach dem Vorbild der umsatzstärksten Simulatoren (*Pet Simulator 99*, *Bee Swarm*, *Pet Catchers*). Alles ist selbst gebaut: eigene Haustiere aus Parts, kein fremder Code, keine fremden Assets.

## Warum dieses Konzept?

- **Bewährter Dauerbrenner.** Pet-Simulatoren gehören seit Jahren zu den umsatzstärksten Roblox-Genres. Sammeltrieb (seltene Haustiere, goldene Versionen) hält Spieler lange im Spiel, und lange Spielzeit bringt auch **Premium Payouts**.
- **Einfach zu verstehen, auch auf dem Handy.** Hinlaufen, Haustiere greifen automatisch an, Münzen sammeln, Eier öffnen. Antippen reicht.
- **Viele Gründe zu zahlen.** Ungeduld (Triple Hatch, Auto Hatch, Münz-Pakete), Glück (Lucky, Server Luck), Stärke (+3 Haustiere, 2x Coins) und Status (VIP-Tag, goldene Haustiere, Server-Ansagen bei Legendary/Mythic).
- **Regelkonform.** Eier gibt es **nur für Münzen**, nie direkt für Robux. Die Chancen stehen offen an jedem Ei (inklusive des eigenen Glücks). In Ländern, in denen bezahlte Zufallsinhalte verboten sind (Roblox `PolicyService`), werden Münz-Pakete, Lucky und Server Luck automatisch ausgeblendet.

## Gameplay-Loop

1. **Farmen:** Haustiere greifen Münzhaufen, Truhen und Tresore in der Nähe automatisch an. Antippen wählt ein Ziel.
2. **Eier öffnen:** Am Ei jeder Zone **[E] Hatch** (oder **[R] Hatch x3** mit Pass). Chancen stehen am Ei.
3. **Zonen freischalten:** 6 Zonen (Meadow → Desert → Frost → Lava → Candy → Space), jedes Tor kostet Münzen. Jede Zone hat stärkere Haustiere und mehr Münzen.
4. **Goldene Haustiere:** 5 gleiche Haustiere → 1 goldenes mit 3x Stärke.
5. **Rebirth:** Ab der letzten Zone und 1 Mrd. Münzen. Münzen und Zonen werden zurückgesetzt, Haustiere bleiben, dauerhaft +0,5x Münzen.
6. **Tägliches Geschenk** am Spawn und **Community-Ränge** nach aktiver Spielzeit (wie bei Steal a Critter: /rank, /yes, /votekick, /announce, /kick, Owner: /ban, /unban, /revoke, /restore).

## Monetarisierung (eingebaut)

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Pass | VIP | 249 R$ | x1,5 Münzen + [VIP]-Tag im Chat |
| Pass | 2x Coins | 399 R$ | doppelte Münzen |
| Pass | Triple Hatch | 349 R$ | 3 Eier auf einmal (Prompt ist für alle sichtbar = Werbung) |
| Pass | Auto Hatch | 299 R$ | öffnet Eier automatisch, solange man daneben steht |
| Pass | +3 Pets Equipped | 299 R$ | 6 statt 3 Haustiere kämpfen |
| Pass | Lucky | 249 R$ | x1,5 Chance auf Rare und besser |
| Pass | Speed | 99 R$ | schneller laufen |
| Produkt | Coin Bag / Chest / Vault | 49 / 199 / 699 R$ | Münzen für 4 / 20 / 80 Eier der besten Zone (wächst mit) |
| Produkt | 2x Coins (30 min) | 79 R$ | Boost |
| Produkt | Server Luck x2 | 199 R$ | 15 min x2 Glück **für alle** (wird groß angesagt = Social Proof) |
| Produkt | +50 Pet Storage | 99 R$ | mehr Platz im Inventar |
| Passiv | Premium-Bonus | – | x1,2 Münzen für Premium-Spieler |

Pässe werden wie bei Steal a Critter als dauerhafte Developer Products verkauft (per API anlegbar). Kaufabwicklung: `ProcessReceipt` mit Kaufhistorie gegen doppelte Vergabe und sofortigem Speichern.

## Projektstruktur (Rojo)

```
games/petsim/
  default.project.json
  roblox.json                   ← Universe- und Place-ID (leer, bis die Experience existiert)
  experience.json               ← Name, Beschreibung, Servergröße
  products.json                 ← Produkte, die per Action angelegt werden
  src/shared/Config.luau        ← alle Zahlen, Zonen, Eier, Haustiere, Preise, Produkt-IDs
  src/shared/PetFactory.luau    ← Haustier-Modelle aus Parts
  src/server/Services/
    DataService.luau            ← Speichern (DataStore, Autosave, BindToClose)
    WorldService.luau           ← baut Zonen, Tore, Eier, Spawn, Geschenk per Code
    BreakableService.luau       ← Münzhaufen/Truhen/Tresore, Schaden, Belohnung
    PetService.luau             ← Inventar, Ausrüsten, Eier, Golden, Tore, Rebirth
    MonetizationService.luau    ← Pässe, Produkte, Premium, Server Luck, Länder-Regeln
    CommunityService.luau       ← Ränge und Moderation (aus Steal a Critter)
  src/client/
    init.client.luau            ← Tore lokal öffnen, Chancen an Eiern, Chat-Tags
    PetFollow.luau              ← Haustiere folgen dem Spieler (nur lokal gerendert)
    UI.luau                     ← HUD, Inventar, Shop, Rebirth, Schlüpf-Animation
```

## Veröffentlichung (automatisch)

Die Actions `publish-petsim.yml`, `products-petsim.yml` und `configure-petsim.yml` laufen bei jedem Push auf `main`, sobald in `roblox.json` die IDs stehen. Sie nutzen dasselbe Secret `ROBLOX_API_KEY` wie Steal a Critter. Der API-Schlüssel braucht dafür Zugriff auf die neue Experience.

## Nächste Ausbaustufen (größter Hebel zuerst)

1. **Icon und Thumbnails** mit seltenen Haustieren (Klickrate entscheidet über die Reichweite).
2. **Neue Zone + Ei jede Woche** (je eine Zeile in `Config.Zones`, `Config.Eggs`, `Config.Pets`) und Events mit Server Luck.
3. **Handel zwischen Spielern** (stärkster Wachstumshebel des Genres, braucht Schutz gegen Betrug).
4. **Rainbow-Stufe** (5 goldene → 1 Rainbow) und ein Sammel-Index.
5. **Gruppen-Bonus** für Mitglieder der Roblox-Gruppe.
