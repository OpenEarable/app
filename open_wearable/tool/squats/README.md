# Kniebeugen: lokale Entwicklung und Replay

Aus `open_wearable/`:

```bash
dart run tool/squats/replay.dart
# Optional: anderer Rohdatenordner, darunter dieselben anonymen IDs
dart run tool/squats/replay.dart /pfad/zu/lokalen/daten
# Nur wenn das Exportformat tatsächlich rad/s liefert:
dart run tool/squats/replay.dart --gyro-unit=rad/s
# Anonymisierte Replay-Ergebnisse aktualisieren:
dart run tool/squats/replay.dart > tool/squats/results.json
flutter test test/tool/squat_recordings_test.dart
```

`manifest.json` hält stabile, anonyme Aufnahme-IDs, ursprüngliche relative
Ordnernamen und die dort genannte Aktivitätsreihenfolge fest. Der letzte
Originalordnername hat ein abschließendes Leerzeichen; es ist im Manifest
absichtlich erhalten. Lokal liegen pro ID ausschließlich `accelerometer.csv`
und `gyroscope.csv` unter `data/<id>/`. Die CSVs wurden unverändert kopiert.
Ein anderer Datenordner muss diese Struktur verwenden; Originalordner mit
Gerätepräfixen werden nicht automatisch gesucht.

| ID | Reihenfolge laut Ordnername | Erwartete Kniebeugen |
|---|---|---:|
| squat-01 | 10 Kniebeugen | 10 |
| squat-02 | 5 Kniebeugen, Gehen, 5 Kniebeugen | 10 |
| squat-03 | 5 Kniebeugen, Hinsetzen, 5 Kniebeugen | 10 |
| squat-04 | 5 Kniebeugen, 3 Liegestütze, 5 Kniebeugen | 10 |
| squat-05 | 5 Kniebeugen, Treppen und Gehen, 5 Kniebeugen, Hinsetzen, 5 Kniebeugen, 3 Liegestütze | 15 |

Die Ordnernamen beschreiben **geordnete Aktivitätsfolgen**, nicht durchgehend
Kniebeugen. Gehen, Treppen, Hinsetzen und Liegestütze bleiben vollständig im
Replay und dienen als Negativkontrollen für den manuell gewählten Squat-Modus.

## Aussagegrenzen

Die Sollzahlen (insgesamt 55) stammen **nur aus den Ordnernamen**, nicht aus
unabhängig überprüfter zeitlicher Ground Truth. Es gibt keine annotierten
Start-/Endzeiten einzelner Übungen oder Wiederholungen. „Treppen und Gehen“
ist daher ein gemeinsamer Abschnitt ohne gesicherte interne Reihenfolge.
Personenzahl, Personenidentität, tatsächliches Messdatum, genaue Ausführung,
Referenzmessung und Gerätekonfiguration sind unbekannt. Aus dem Downloadnamen
oder den Gerätezeitstempeln wird kein Messdatum abgeleitet. Die im Replay
berechneten Sensorraten sind beobachtete Durchschnittsraten einschließlich
Lücken, keine zugesicherten Konfigurationswerte. Übereinstimmende Gesamtzahlen
belegen weder korrekte Ereigniszuordnung noch personenunabhängige Genauigkeit.
Ohne zeitliche Annotationen lassen sich weder ereignisspezifische False
Positives/False Negatives noch Erkennungsgenauigkeit bestimmen; auch Fehler
in unterschiedlichen Abschnitten können sich in der Gesamtzahl aufheben.
Diese Aufnahmen sind Entwicklungsdaten, kein unabhängiger Validierungssatz.

## Beobachtete Ausgangsbasis vor der Squat-Überarbeitung

Die folgenden Gesamtzahlen wurden mit der bisherigen Engine im vollständigen
Replay beobachtet und vom Integrationslauf übernommen; sie sind keine Ergebnisse
des überarbeiteten Detektors und wurden hier nicht erneut ausgeführt.

| ID | Soll laut Ordnername | Bisher erkannt | Differenz erkannt − Soll |
|---|---:|---:|---:|
| squat-01 | 10 | 0 | −10 |
| squat-02 (Gehen) | 10 | 0 | −10 |
| squat-03 (Hinsetzen) | 10 | 4 | −6 |
| squat-04 (Liegestütze) | 10 | 0 | −10 |
| squat-05 (lange Mischfolge) | 15 | 7 | −8 |

Bei drei der fünf Aufnahmen wurde die bisherige Engine nie kalibriert; in der
langen Mischfolge wurden zwei Datenlücken beobachtet. Diese Beobachtungen
motivieren eine Squat-spezifische Startkalibrierung, ohne das Startverhalten
anderer Modi zu verändern. Ein Replay darf die Kalibrierungsprobleme nicht durch
künstliche Stilldaten oder Wiederherstellung einer Kalibrierung verdecken.
Auch die Ausgangszahlen erlauben keine Zuordnung einzelner Ereignisse zu
Kniebeugen oder Negativkontrollen. Neue Ergebnisse entstehen ausschließlich
durch den oben angegebenen Lauf mit der tatsächlich überarbeiteten Engine.

## Verarbeitung und Ergebnisfelder

- Header: `timestamp,X,Y,Z`; Zeitstempel werden als Unix-Mikrosekunden gelesen,
  Beschleunigung als m/s². Die Gyroeinheit steht nicht im CSV: **deg/s ist eine
  Annahme**, standardmäßig erfolgt die Umrechnung zu rad/s; explizit
  `--gyro-unit=deg/s` oder `--gyro-unit=rad/s` wählen. Keine automatische
  Einheitenheuristik, um stilles Verfälschen des Signals zu vermeiden.
- Sessionnull ist der früheste Zeitstempel beider Sensoren. Erst werden die
  ganzzahligen Mikrosekunden subtrahiert, dann relative Sekunden gebildet.
- Für jeden Beschleunigungspunkt wird der zeitlich nächste Gyropunkt innerhalb
  von einschließlich 20 ms gewählt, wie im Live-Datenpfad; bei Gleichstand der
  frühere. Gyropunkte
  dürfen wie im Live-Puffer mehrfach verwendet werden; nicht gewählte Gyropunkte
  zählen als `unmatchedGyroscope`. Keine Interpolation oder künstlichen Werte.
- Jeder Beschleunigungspunkt bleibt erhalten. Fehlendes passendes Gyro ist
  explizit `null`; das Replay setzt den echten `ActivityEngine` zurück, statt
  Nullgeschwindigkeit anzunehmen oder kurze Unterbrechungen herauszufiltern.
  `unmatchedGyroscopeInterruptionSpans` zählt zusammenhängende solche Lücken.
  Größere Beschleunigungszeitlücken behandelt zusätzlich die Engine selbst.
- Der echte `ActivityEngine` läuft vom ersten Beschleunigungspunkt an im Modus
  `squats`, auch während Gehen, Hinsetzen und Liegestützen. Keine künstliche
  Stillphase, wiederhergestellte Kalibrierung oder nachträgliche Segmentauswahl.
- JSON enthält pro Aufnahme `expected`, `detected` und den vorzeichenbehafteten
  `error = detected - expected`, Sessiondauer, Sensorraten, Punktzahlen und
  nicht zugeordnete Punkte. `calibratedSampleFraction` ist der Anteil aller
  Beschleunigungspunkte, nach deren Verarbeitung die Engine kalibriert war
  (fehlendes Gyro zählt unkalibriert). `firstCalibrationSeconds` ist die erste
  erfolgreiche Kalibrierung relativ zur Sessionnull, sonst `null`.
  `detectedEventSeconds` sind Bestätigungszeiten der Engine, keine annotierten
  Ground-Truth-Zeiten. Es gibt keinen erzwungenen Abschluss am Aufnahmeende.
- Fehlende/unlesbare Dateien, falsche Header, ungültige/nicht endliche Zahlen,
  leere Sensorreihen und nicht streng steigende Zeitstempel ergeben Fehler auf
  stderr und Exitcode 1. Ungültige CLI-Argumente ergeben 64. stdout enthält nur
  erfolgreich geladene Aufnahmen; unvollständige Ergebnisse nicht als vollständige
  Evaluation verwenden. Zähldifferenzen allein ändern den Exitcode nicht.

## Datenschutz

Das Repository ist öffentlich: `data/` und die ursprünglichen Rohaufnahmen
bleiben ausschließlich lokal und dürfen **nicht eingecheckt werden**. Auch
absolute Zeitstempel und Hardware-IDs gehören nicht in Ergebnisse. Manifest
und `results.json` enthalten nur anonyme Metadaten bzw. abgeleitete Kennzahlen
und relative Ereigniszeiten, keine Rohsensorreihen. Der dokumentierte Replay
wurde am 17.11.2026 ausgeführt. Ergebnisse, Begründungen und verbleibende
Zählfehler stehen im [Kniebeugenbericht](../../../docs/algorithmen/kniebeugen.md).
