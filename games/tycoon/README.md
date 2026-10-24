# Magic Garden Tycoon – Garten-Tycoon mit Fokus auf Einnahmen

Ein spielbarer Garten-Tycoon nach dem Vorbild von *Grow a Garden* (2025 das meistgespielte Roblox-Spiel und 2026 weiter aktiv). Alles ist selbst gebaut: eigene Pflanzen aus Parts, kein fremder Code, keine fremden Assets.

## Warum dieses Konzept?

- **Riesige Reichweite.** Garten-Tycoons sind einfach zu verstehen, laufen sehr gut auf Mobile und sprechen junge Spieler an.
- **Spieler kommen zurück.** Pflanzen wachsen auch offline weiter, der Samenladen füllt sich alle 5 Minuten neu auf (in allen Servern gleich, "Mythic im Laden!" spricht sich herum) und es gibt eine 7-Tage-Belohnung. Mehr Spielzeit bedeutet mehr Premium Payouts.
- **Viral.** +10 % Fruchtwert pro Freund im Server (bis +40 %).
- **Regelkonform.** Es gibt keine bezahlten Zufallsitems. Mutationen (Wet, Shocked, Golden, Rainbow) sind kostenloser Zufall beim Ernten. Für Robux bekommt man immer genau das, was angezeigt wird.

## Gameplay-Loop

1. Am **SEEDS**-Stand Samen kaufen (Angebot wechselt alle 5 Minuten, Common bis Mythic).
2. Samen unten in der Leiste wählen und auf die braune Erde im eigenen Garten tippen.
3. Reife Pflanzen antippen = ernten. Viele Pflanzen wachsen danach wieder nach.
4. Am **SELL**-Stand alles verkaufen.
5. **UPGRADES**: neue Felder (8 bis 24), Sprinkler (+10 % Wachstum pro Stufe), Dünger (+10 % Wert pro Stufe), Rebirth (+0,5x Wert dauerhaft).
6. **Wetter**: Regen (schneller wachsen, Wet x2), Gewitter (Shocked x10). Golden x20 und Rainbow x50 sind selten.

## Monetarisierung (eingebaut)

| Typ | Produkt | Preis | Wirkung |
|---|---|---|---|
| Dauerhaft | VIP | 249 R$ | x1,5 Fruchtwert + VIP-Tag |
| Dauerhaft | 2x Sell | 399 R$ | doppelter Fruchtwert |
| Dauerhaft | Auto Harvest | 349 R$ | reife Pflanzen ernten sich selbst |
| Dauerhaft | Fast Grow | 299 R$ | alles wächst doppelt so schnell |
| Dauerhaft | Big Garden | 299 R$ | +12 Felder (gesperrte Felder sind im Garten sichtbar = Werbung) |
| Produkt | Coin Pouch / Chest / Vault | 49 / 199 / 699 R$ | 10 min / 1 h / 6 h Verdienst (wächst mit dem Spieler mit) |
| Produkt | Grow All Now | 39 R$ | ganzer Garten sofort reif |
| Produkt | Summon Rain / Thunderstorm | 99 / 199 R$ | Wetter für den ganzen Server (wird groß angesagt) |
| Produkt | Golden Hour | 249 R$ | 10 min lang 10x Golden-Chance für alle |
| Produkt | Dragon Fruit / Starfruit Seed | 99 / 299 R$ | genau dieser Samen |
| Passiv | Premium-Bonus | – | Premium-Spieler bekommen x1,2 |

Die "dauerhaften" Vorteile werden als Developer Products verkauft und gespeichert, damit alles per API angelegt werden kann. Kaufabwicklung über `ProcessReceipt` mit Kaufhistorie und sofortigem Speichern.

## Community-Ränge

Wie in Steal a Critter: Ränge nach aktiver Spielzeit (Member, Regular, Veteran, Guardian), Owner BigBabaAli. Chat-Befehle `/rank /yes /votekick /announce /kick /ban /unban /revoke /restore`, schimmernde Namensschilder.

## Veröffentlichen

Läuft automatisch über `.github/workflows/publish-tycoon.yml` bei jedem Push auf `main` in `games/tycoon/`:

1. Experience finden: IDs aus `roblox.json` oder die Experience des API-Schlüssels, deren Name "Garden" enthält.
2. Fehlende Developer Products aus `products.json` anlegen und ihre IDs in `src/shared/ProductIds.json` einbauen.
3. Name, Beschreibung und Servergröße (8) aus `experience.json` setzen.
4. Mit Rojo bauen und veröffentlichen.

Einmalig von Hand nötig: eine neue Experience anlegen, den API-Schlüssel dafür freigeben und sie auf Öffentlich stellen.

## Projektstruktur (Rojo)

```
default.project.json
src/shared/Config.luau          ← alle Zahlen, Samen, Mutationen, Wetter, Preise
src/shared/ProductIds.json      ← wird beim Veröffentlichen erzeugt
src/server/Services/
  DataService.luau              ← Speichern (DataStore, Autosave, BindToClose)
  WorldService.luau             ← baut Marktplatz und einen Garten pro Spieler per Code
  GardenService.luau            ← Pflanzen, Wachstum (auch offline), Ernte, Verkauf, Upgrades, Rebirth, Tagesbelohnung, Freunde
  EventService.luau             ← Samenladen mit Restock und Wetter
  MonetizationService.luau      ← dauerhafte Vorteile, Developer Products, Premium
  CommunityService.luau         ← Ränge und Moderation
src/client/init.client.luau     ← Chat-Tags, Namensschilder
src/client/UI.luau              ← HUD, Samenleiste, Samenladen, Upgrades, Store
```
