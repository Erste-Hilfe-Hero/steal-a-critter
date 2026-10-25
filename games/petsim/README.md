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
6. **Tägliches Geschenk** (mit Serie) am Spawn und **Community-Ränge** nach aktiver Spielzeit (wie bei Steal a Critter: /rank, /yes, /votekick, /announce, /kick, Owner: /ban, /unban, /revoke, /restore).

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
  roblox.json                   ← Universe/Place-ID (leer = automatisch per Name finden)
  experience.json               ← Name, Beschreibung, Servergröße
  products.json                 ← Produkte, die per Action angelegt werden
  src/shared/ProductIds.json    ← wird von der Action beim Veröffentlichen erzeugt
  src/shared/Config.luau        ← alle Zahlen, Zonen, Eier, Haustiere, Preise, Produkt-IDs
  src/shared/PetFactory.luau    ← Haustier-Modelle aus Parts
  src/server/Services/
    DataService.luau            ← Speichern (DataStore, Autosave, BindToClose)
    WorldService.luau           ← baut Zonen, Tore, Eier, Spawn, Geschenk per Code
    BreakableService.luau       ← Münzhaufen/Truhen/Tresore, Schaden, Belohnung
    PetService.luau             ← Inventar, Ausrüsten, Eier, Golden, Tore, Rebirth
    MonetizationService.luau    ← Pässe, Produkte, Premium, Server Luck, Länder-Regeln
    CommunityService.luau       ← Ränge und Moderation (aus Steal a Critter)
    ProgressService.luau        ← Aufgaben, Erfolge/Titel, Index, Geschenke, Codes, Einstellungen, Happy Hour, Bestenlisten
  src/client/
    init.client.luau            ← Tore lokal öffnen, Chancen an Eiern, Chat-Tags
    PetFollow.luau              ← Haustiere folgen dem Spieler (nur lokal gerendert)
    UI.luau                     ← HUD, Inventar, Shop, Rebirth, Schlüpf-Animation
```

## Veröffentlichung (automatisch)

Die Action `publish-petsim.yml` läuft bei jedem Push auf `main` (oder per Hand unter *Actions*). Sie nutzt dasselbe Secret `ROBLOX_API_KEY` wie Steal a Critter und findet die Experience selbst: unter allen Experiences, für die der Schlüssel freigegeben ist, nimmt sie die, deren Name "Hatch" oder "Pet" enthält. Dann legt sie fehlende Produkte an, baut die IDs ins Spiel ein, setzt Name und Beschreibung und veröffentlicht. Solange keine passende Experience existiert, wird nur gebaut.

## Update: Fehlerbehebungen und 15 neue Funktionen

### Behobene Fehler
1. **Votekick-Timer:** Verließ das Ziel einer Abstimmung den Server, beendete der alte Timer später eine *neue* Abstimmung vorzeitig. Jetzt gehört jeder Timer zu genau seiner Abstimmung.
2. **ProcessReceipt:** Bei einem erneuten Versuch nach fehlgeschlagenem Speichern wurde `PurchaseGranted` gemeldet, ohne dass gespeichert war. Jetzt erst nach erfolgreichem Speichern.
3. **Spieler verlässt beim Laden:** Ging ein Spieler, während Pässe/Länder-Regeln geladen wurden, blieb er für immer in der AFK-Liste (Speicherleck, Schleife lief weiter). Jetzt Abbruch, wenn der Spieler weg ist.
4. **Auto Hatch-Spam:** Ohne Münzen oder bei vollem Inventar kam alle 2,5 s dieselbe rote Meldung. Jetzt schaltet sich Auto Hatch mit einer Meldung ab.
5. **Triple Hatch:** Mit Münzen für 1–2 Eier passierte gar nichts. Jetzt werden so viele Eier geöffnet, wie bezahlbar sind.
6. **Remote-Spam:** Ausrüsten/Löschen/Golden konnten beliebig oft pro Sekunde gesendet werden (jedes Mal ganzes Inventar zurück). Jetzt höchstens ~10x pro Sekunde.
7. **„Delete Unequipped Commons“** löschte auch Uncommons und das ohne Rückfrage. Jetzt heißt der Knopf „Delete Commons & Uncommons“ und braucht ein zweites Tippen.
8. **Münz-Anzeige beim Laden:** `leaderstats` wurde beim Laden nicht begrenzt (bei sehr vielen Münzen konnte das Laden abbrechen); jetzt wie beim Aktualisieren begrenzt.
9. **Typfehler** in der Spielersuche der Befehle (`/kick`, `/votekick` …) behoben (luau-lsp jetzt ohne Fehler).

### 15 neue Funktionen
1. **Tägliche Serie:** Das Tagesgeschenk wächst jeden Tag in Folge (+50 % bis Tag 7), jeder 7. Tag schenkt zusätzlich 15 min 2x Coins. Ein verpasster Tag setzt die Serie zurück.
2. **Tagesaufgaben:** Jeden Tag 3 Aufgaben (zerstören, schlüpfen, Truhen, Antippen, Spielzeit, Geschenke) mit Münz-Belohnung, Fenster „Quests“ mit Fortschrittsbalken.
3. **Erfolge:** 12 Meilensteine (z. B. 100 Eier, 5.000 Zerstörungen, erste goldene/Regenbogen-Haustiere, Zonen, Rebirth, Index, Serie) mit Münz-Belohnung.
4. **Titel:** Jeder Erfolg schaltet einen Titel frei, der über dem Kopf und im Chat erscheint.
5. **Sammel-Index:** Buch mit allen Haustieren (unentdeckte als „?“); jedes komplett entdeckte Ei gibt dauerhaft +5 % Münzen.
6. **Regenbogen-Haustiere:** 5 gleiche goldene → 1 Regenbogen-Haustier (6x Stärke, Farbe wechselt ständig, Server-Ansage).
7. **Haustiere sperren:** Gesperrte Haustiere können nicht gelöscht oder verbraucht werden (🔒 auf der Karte).
8. **Antippen macht Schaden:** Jedes Tippen auf Münzhaufen/Truhen macht 30 % der eigenen Stärke als Extra-Schaden (mit Anzeige und Ton, Abklingzeit gegen Autoklicker).
9. **Spielzeit-Geschenke:** 6 Geschenke nach 5–60 Minuten pro Besuch (Münzen und Boosts).
10. **Happy Hour:** In allen Servern gleichzeitig alle 20 Minuten 3 Minuten doppelte Münzen, mit Ansage und Countdown im HUD.
11. **Codes:** Code-Feld im Gifts-Fenster. Aktuelle Codes: `RELEASE` (Münzen für 3 Eier), `HATCHTIME` (Münzen für 5 Eier), `SPEEDY` (10 min 2x Coins). Neue Codes in `Config.Codes`.
12. **Globale Bestenlisten:** Zwei Tafeln am Spawn (Top Hatchers, Top Rebirths), alle 2 Minuten aktualisiert.
13. **Schnellreise:** Fenster „Travel“ teleportiert in jede freigeschaltete Zone.
14. **Einstellungen:** Töne, Haustiere anderer Spieler (spart Leistung auf dem Handy), Münz-Popups und Ziel-Hinweis ein/aus, gespeichert.
15. **Ziel-Hinweis mit Pfeil:** Neue Spieler sehen oben ihr nächstes Ziel (Geschenk abholen, erstes Ei, nächstes Tor …) und einen leuchtenden Pfeil dorthin.

Das Menü links hat jetzt zwei Spalten (8 Knöpfe), damit alles auch auf kleinen Handys passt. Keine neuen Robux-Produkte; Eier gibt es weiterhin nur für Münzen.

## Nächste Ausbaustufen (größter Hebel zuerst)

1. **Icon und Thumbnails** mit seltenen Haustieren (Klickrate entscheidet über die Reichweite).
2. **Neue Zone + Ei jede Woche** (je eine Zeile in `Config.Zones`, `Config.Eggs`, `Config.Pets`) und Events mit Server Luck.
3. **Handel zwischen Spielern** (stärkster Wachstumshebel des Genres, braucht Schutz gegen Betrug).
4. **Gruppen-Bonus** für Mitglieder der Roblox-Gruppe.
