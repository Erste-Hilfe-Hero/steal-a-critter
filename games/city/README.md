# Turbo City – Cops & Robbers mit Fokus auf Einnahmen

Eine offene Comic-Stadt im Stil von *GTA*, aber kindgerecht (Ziel: Altersfreigabe Mild 9+): Autos fahren, Jobs erledigen, als Räuber Beute holen oder als Polizist Räuber fangen, Häuser und Garagen kaufen. Kein Blut, keine echten Waffen: Die Polizei hat Handschellen und einen Comic-Stun-Blaster. Name, Stadt, Autos und Grafiken sind komplett selbst gebaut, nichts von Rockstar.

## Warum dieses Konzept?

- **Bewährtes Genre.** Cops & Robbers (wie *Jailbreak*) und Stadt-Rollenspiele (wie *Brookhaven*) gehören seit Jahren zu den meistgespielten Roblox-Spielen.
- **Geld überall.** Jede Aktion bringt Cash: Lieferungen, Rennen, Überfälle, Festnahmen, Hausmiete (auch offline), Tagesbelohnung, Geschenke, Missionen und Codes. Damit gibt es immer ein nächstes Auto oder Haus, auf das man spart, und die Robux-Abkürzung liegt nah.
- **Spieler kommen zurück.** Offline-Miete, 7-Tage-Belohnung, tägliche Missionen, Bestenliste.
- **Regelkonform.** Keine bezahlten Zufallsitems. Für Robux bekommt man immer genau das, was angezeigt wird.

## Gameplay-Loop

1. Jeder startet als **Bürger**. Am Platz in der Mitte (oder über **TEAM**) wechselt man zu **Räuber** oder **Polizei** (Polizei ist auf einen Teil des Servers begrenzt).
2. Unten **CAR** tippen: das eigene Auto erscheint an der Haus-Einfahrt oder an der nächsten Straße. Boost- und Sprungpads in der ganzen Stadt.
3. **Bürger:** Pakete am Depot abholen und ausliefern (Ketten werden immer mehr wert), Stadtrennen fahren.
4. **Räuber:** Bank, Juwelier, Tankstelle oder Donut-Laden ausrauben (gedrückt halten), die Beute im Versteck einzahlen. Jeder Überfall gibt Fahndungssterne und alarmiert die Polizei.
5. **Polizei:** Räuber mit Handschellen festnehmen, Autos mit dem Stun-Blaster stoppen. Pro Stern gibt es Kopfgeld. Gefangene sitzen kurz im Gefängnis (oder kaufen **Jail Break**).
6. Geld ausgeben: 11 Autos (Bubble bis Hyperion für 3,5 Mio.), Lackfarben und 7 Häuser vom Wohnwagen bis zum Diamond Penthouse. Je besser das Haus, desto mehr Miete pro Minute.

## Monetarisierung (eingebaut)

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 249 R$ | x1,5 Cash, VIP-Tag, Gold-Lack |
| Dauerhaft | 2x Cash | 399 R$ | doppeltes Cash bei allem |
| Dauerhaft | Nitro | 149 R$ | Nitro-Boost in jedem Auto (wird nach der 3. Fahrt angeboten) |
| Dauerhaft | Big Loot Bag | 199 R$ | doppelte Beute, halb so lange halten |
| Dauerhaft | Rocket Kart | 299 R$ | schnellstes Auto der Stadt |
| Dauerhaft | SWAT Team | 199 R$ | SWAT-Wagen und +50 % Kopfgeld |
| Dauerhaft | Neon Underglow | 99 R$ | Neon-Unterbodenlicht und Regenbogen-Lack |
| Dauerhaft | Diamond Penthouse | 499 R$ | bestes Haus, 12.000 $ Miete pro Minute |
| Produkt | Cash Stack / Briefcase / Truck | 49 / 199 / 699 R$ | Cash, wächst mit dem Haus mit |
| Produkt | Jail Break | 25 R$ | sofort aus dem Gefängnis (Knopf direkt in der Zelle) |
| Produkt | Clear Wanted | 35 R$ | alle Fahndungssterne weg |
| Produkt | Cash Party | 199 R$ | 10 min doppeltes Cash für den ganzen Server (wird angesagt) |
| Produkt | Money Rain | 99 R$ | Geldregen über der ganzen Stadt |
| Produkt | Mission Skip | 29 R$ | nächste Tagesmission sofort fertig |
| Produkt | Starter Pack | 79 R$ | einmalig 50.000 $ + Zoomer GT (Angebot nach 4 Minuten) |
| Werbung | Free Cash | – | Belohnungs-Video über AdService |
| Passiv | Premium-Bonus | – | Premium-Spieler bekommen x1,2 |

Angebote erscheinen passend zur Situation: Jail Break im Gefängnis, Clear Wanted bei vielen Sternen, Cash-Pakete, wenn das Geld für ein Auto oder Haus knapp nicht reicht. Die dauerhaften Vorteile werden als Developer Products verkauft und gespeichert, damit alles per API angelegt werden kann.

Codes zum Start: `TURBO`, `RELEASE`, `COPS`, `ROBBERS`.

## Stil

Eigener Comic-Pop-Look: dunkles Tinten-Blau mit Orange, Pink, Türkis und Zitronengelb, dicke Konturen, harte Schatten, Schrift *Luckiest Guy*. Ladebildschirm mit fahrendem Auto als Ladebalken, Logo "TURBO CITY" und Banner "COPS & ROBBERS". Tag-Nacht-Wechsel mit Straßenlaternen und Blaulicht.

## Icon und Vorschaubilder

`assets/icon.png` (512×512), `assets/thumbnail.png` und `assets/thumbnail_heist.png` (1920×1080). Neu erzeugen mit `python3 assets/make_art.py <LuckiestGuy.ttf> assets`. Hochgeladen werden sie über `media.yml`.

## Veröffentlichen

Läuft automatisch über `.github/workflows/publish-city.yml` bei jedem Push auf `main` in `games/city/`:

1. Experience finden: Alis Experience "3" (Universe `10772779320`) ist in `roblox.json` festgelegt, die Place-ID kommt aus dem Inventar des Besitzers.
2. Fehlende Developer Products aus `products.json` anlegen und ihre IDs in `src/shared/ProductIds.json` einbauen.
3. Name, Beschreibung und Servergröße (20) aus `experience.json` setzen.
4. Mit Rojo bauen, als Entwurf hochladen, den Smoke-Test (`tests/smoke.luau`) im echten Roblox laufen lassen und nur bei grünem Test veröffentlichen.

Icon und Vorschaubilder lädt `.github/workflows/media.yml` hoch (Eintrag in `media.json`). Einmalig von Hand nötig: das englische Haupt-Icon im Creator Hub setzen und auf Öffentlich stellen.

## Projektstruktur (Rojo)

```
default.project.json
src/shared/Config.luau          ← alle Zahlen: Autos, Häuser, Überfälle, Missionen, Codes, Preise
src/shared/ProductIds.json      ← wird beim Veröffentlichen erzeugt
src/first/LoadingScreen.client.luau ← Ladebildschirm
src/server/Services/
  DataService.luau              ← Speichern, Multiplikatoren, Cash
  Build.luau                    ← Bau-Helfer (Kästen, Schilder, Bäume, Hochhäuser)
  WorldService.luau             ← baut die ganze Stadt per Code (6×6 Blöcke, Strand, Gefängnis, Versteck)
  VehicleService.luau           ← Autos bauen, spawnen, kaufen, lackieren
  HouseService.luau             ← 24 Grundstücke, 7 Haus-Stufen, Miete
  JobService.luau               ← Teams, Polizei, Gefängnis, Überfälle, Lieferungen, Rennen
  MonetizationService.luau      ← Vorteile, Developer Products, Angebote, Werbung
  RewardService.luau            ← Missionen, Tagesbelohnung, Geschenke, Codes, Bestenliste
  CommunityService.luau         ← Ränge und Moderation
src/client/Drive.luau           ← Arcade-Fahrsteuerung mit Nitro
src/client/Effects.luau         ← GPS-Marker, Sterne, Blaulicht, Laternen
src/client/UI.luau              ← HUD, Shop, Garage, Haus, Team, Missionen
tests/smoke.luau                ← Test vor jedem Veröffentlichen
```
