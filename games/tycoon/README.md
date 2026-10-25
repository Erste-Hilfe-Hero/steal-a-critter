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

## Update 2 (Oktober 2026)

### Behobene Fehler

1. Wer das Spiel während der Bann-Prüfung verließ, bekam trotzdem einen Garten zugewiesen. Der Garten blieb dann für immer belegt.
2. Freundes-Bonus: Beim Verlassen wurden Freundschaften anderer Spieler gelöscht, deren UserId zufällig dieselben Ziffern enthielt.
3. Vote-Kick: Der Timer einer abgebrochenen Abstimmung konnte eine neuere Abstimmung zu früh beenden.
4. Natürliches Wetter konnte ein gekauftes Gewitter oder einen gekauften Regen überschreiben.
5. Samenladen: Der eigene Vorrat hing am Player-Objekt. Nach dem Neu-Beitreten konnte man seltene Samen erneut kaufen.
6. Store: "OWNED" wurde manchmal von der verspäteten Preisabfrage wieder mit dem Preis überschrieben.
7. ProcessReceipt hat Käufe vergeben, obwohl die Spielerdaten nicht geladen waren (sie wären nie gespeichert worden). Jetzt gilt NotProcessedYet, und Roblox liefert den Kauf später erneut aus.
8. Upgrades erschienen in zufälliger Reihenfolge. Jetzt ist die Reihenfolge fest.
9. Rebirth ohne Sicherheitsabfrage: Ein versehentlicher Tipp auf dem Handy setzte alles zurück. Jetzt muss man zweimal tippen. Der Hinweistext nennt jetzt auch die Früchte.
10. "Grow All Now" (39 R$) ließ sich auch mit leerem Garten kaufen. Jetzt erscheint stattdessen ein Hinweis.
11. Meldungen stapelten sich ohne Grenze und verdeckten auf dem Handy das HUD. Beim Ausblenden blieb außerdem der Hintergrund stehen.
12. Wer einen gewöhnlichen Samen kaufte, bekam keine Rückmeldung.
13. Zeiten über einer Stunde (z. B. eine verlängerte Golden Hour) wurden als "75:00" angezeigt. Jetzt erscheinen sie als h:mm:ss.
14. Typfehler in der Spielersuche (findPlayer) beseitigt. Zusätzlich prüft der Server beim Pflanzen, ob das Feld dem Spieler gehört und frei ist.

### 15 neue Features

1. **Schaufel** in der Samenleiste: Pflanzen ausgraben, damit das Feld wieder frei ist. Bei Legendary und Mythic muss man zur Sicherheit zweimal tippen.
2. **PLANT ALL**: bepflanzt alle freien Felder mit dem gewählten Samen.
3. **Rucksack-Upgrade** (+25 Plätze pro Stufe, bis zu 10 Stufen) unter UPGRADES.
4. **Tagesaufgaben** (QUESTS): jeden Tag 3 neue Aufgaben in drei Schwierigkeiten. Die Belohnung (Münzen und XP) wächst mit dem Verdienst.
5. **Erfolge mit Titeln** (BOOK): 14 Erfolge. Jeder schaltet einen Titel frei, der über dem Namensschild steht.
6. **Pflanzen-Index** (BOOK): Jede entdeckte Pflanze und Mutation gibt dauerhaft +2 % Fruchtwert.
7. **Gärtner-Level**: XP fürs Ernten, ein XP-Balken im HUD und "Level" in der Rangliste. Jede Stufe bringt Münzen und +1 % Fruchtwert.
8. **Glücksrad** (WHEEL): alle 4 Stunden eine kostenlose Drehung (kein Robux). Mögliche Gewinne: Münzen, Samen bis Mythic oder 10 Minuten 2x Sell. Die Chancen stehen offen im Fenster.
9. **Codes** (SETTINGS): GARDEN, SPROUT, MAGIC, RAINBOW. Jeder Code ist einmal pro Konto einlösbar.
10. **Einstellungen**: Sound-Effekte, große Ansagen und die Pets anderer Spieler lassen sich ein- und ausschalten. Die Einstellungen werden gespeichert.
11. **Tag und Nacht** (15-Minuten-Zyklus, in allen Servern gleich). Nachts gibt es die neue Mutation **Moonlit (x3)**.
12. **Pets** (PETS): 5 Begleiter für Münzen (Wachstum, Wert oder Mutationschance). Sie folgen dem Spieler, schweben und bleiben bei Rebirth erhalten.
13. **Garten-Designs**: 6 Boden- und Zaunfarben, für alle sichtbar. "Midnight Bloom" ist ab Level 30 gratis.
14. **Top Gardeners**: eine Tafel am Marktplatz mit den 10 besten Gärtnern aller Server (OrderedDataStore).
15. **Einführung für neue Spieler**: ein Banner mit 4 Schritten und ein leuchtender Leitstrahl zum Ziel. Am Ende gibt es eine Belohnung.

Neue Developer Products (über `products.json`): **Super Backpack** (149 R$, +100 Rucksackplätze für immer) und **Rainbow Unicorn Pet** (399 R$, +50 % Wert, +30 % Wachstum, +30 % Mutationen).

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
  EventService.luau             ← Samenladen mit Restock, Wetter, Tag und Nacht
  ProgressService.luau          ← Aufgaben, Erfolge/Titel, Index, Level, Glücksrad, Codes, Einstellungen, Einführung
  CosmeticService.luau          ← Pets und Garten-Designs
  LeaderboardService.luau       ← Top-Gardeners-Tafel (alle Server)
  MonetizationService.luau      ← dauerhafte Vorteile, Developer Products, Premium
  CommunityService.luau         ← Ränge und Moderation
src/client/init.client.luau     ← Chat-Tags, Namensschilder
src/client/UI.luau              ← HUD, Samenleiste, Samenladen, Upgrades, Store
src/client/Extras.luau          ← Quests, Glücksrad, Pets, Buch, Einstellungen, Einführung
```
