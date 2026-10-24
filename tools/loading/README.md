# Ladebildschirme

Alle Spiele nutzen denselben Kern `LoadingKit.luau`. Jedes Spiel hat in
`src/first/LoadingScreen.client.luau` eine Kopie davon zwischen
`-- >>> LoadingKit` und `-- <<< LoadingKit`, darunter folgt der eigene Stil
(Farben, Logo, Hintergrund-Animation).

Nach einer Aenderung am Kern:

```sh
python3 tools/loading/sync.py          # alle Spiele aktualisieren
python3 tools/loading/sync.py --check  # nur pruefen
```

Was der Kern macht:

- 16:9-Buehne, die auf Handy, Tablet und PC gleich aussieht (Notch bleibt frei)
- Logo springt beim Start auf, Glanzstreifen laeuft darueber; Schriften werden vorgeladen
- Konturen wachsen mit der Bildschirmhoehe (auf dem Handy scharf statt verklumpt)
- echter Fortschritt: `game:IsLoaded()`, Asset-Warteschlange, Remotes, eigene Figur,
  spielspezifische `Checks`; Balken und Prozent laufen weich nach
- Tipp-Karte: wechselt alle 4,5 s, antippen = naechster Tipp
- SKIP-Knopf nach 1,5 s (auch Leertaste / Enter / Gamepad A)
- spaetestens nach 15 s ist der Bildschirm weg, egal was passiert
