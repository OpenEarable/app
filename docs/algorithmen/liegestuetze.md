# Liegestütz-Zählung: Algorithmusprüfung

Stand: 10.11.2026. Manuell gewählter Push-up-Modus, ohne ML.

## Aktueller Stand nach der Lowering-Rückmeldung

Die folgende Historie beschreibt auch verworfene Zwischenstände. Aktuell werden
Geschwindigkeit und Positionsproxy gedämpft, um fortlaufende Offsetdrift zu
begrenzen. Zusätzlich bleibt eine ungedämpfte Referenz für die Rückwegprüfung
erhalten; nahe Ruhe werden Geschwindigkeit und der aktive Proxy angehalten.
Eine zeitbegrenzte Restgeschwindigkeitskorrektur und ein Vergleich von
Spitzengeschwindigkeit × Phasendauer helfen bei kontinuierlichen Zyklen. Nach
einem Halt ist dieser alternative Phasenvergleich deaktiviert, damit die
Wartezeit keine unvollständige Rückkehr vervollständigt. Der Mindestproxyhub
beträgt nun 0,015 m und ist weiterhin keine gemessene anatomische Tiefe.

Eine lokale Aufnahme (ca. 100 Hz, keine Lücken >120 ms) liefert im Replay
6 statt vorher 3 Zählungen. Die Selbstauskunft beträgt nur ungefähr 5–7,
exakte Referenzannotation fehlt. Alle 49 Push-up-Tests bestehen; das ersetzt
keine unabhängige Nutzerevaluation. Rohdaten werden nicht eingecheckt.

## Befund und Entscheidung

Der Prototyp verwendete denselben Detektor wie Squats, lediglich mit anderer
Mindestamplitude. Geschwindigkeit und Position wurden fortlaufend gedämpft.
Dadurch verschwand ein abgesenkter Positionswert während einer Pause, obwohl
keine vollständige Rückbewegung stattfand.

Reproduzierbarer synthetischer Gegenfall: 16 cm Absenken in 0,9 s, 3 s halten,
2 cm zurück in 0,9 s, anschließend 5 s halten. Der alte Code zählte 1, der
korrigierte Code 0 Wiederholungen. Das sind simulierte Kopfbewegungen, keine
Messungen von Liegestütztiefe oder Versuchspersonen.

Ein eigener Push-up-Detektor wurde gewählt, damit die Korrektur den Squat-Zähler
nicht verändert. Die alte Positionsdämpfung wurde verworfen: Sie erzeugt eine
scheinbare Rückkehr. Kontinuierliches Zurücksetzen der Geschwindigkeit wurde
verworfen, weil es bei nahtlosen Wiederholungen neue Integrationsfehler erzeugt.

## Funktionsweise

1. Die gemeinsame IMU-Vorverarbeitung schätzt die Schwerkraftrichtung und glättet
   die projizierte vertikale Beschleunigung.
2. Der Push-up-Detektor verlangt 0,7 s mit ruhigem Beschleunigungs- und Gyrosignal.
   Der Restoffset wird erst nach 0,45 s Filter-Einschwingzeit gemittelt.
3. Die offsetbereinigte Beschleunigung wird kurzfristig integriert. Der
   Positionswert bleibt während einer Pause erhalten.
4. Auf Absenken folgt eine Rückbewegung von mindestens 75 % der geschätzten
   Absenkung. Ein vom Rückbewegungstempo abhängiger Umkehrpunkt bestätigt die Zählung. Eine
   Mindestbewegung und Mindestdauer verwerfen kleine beziehungsweise kurze Zyklen.
5. Nahe Stillstand darf die Geschwindigkeit korrigiert werden, nicht die aktive
   Absenkung. Restgeschwindigkeit bleibt beim Übergang zur nächsten Wiederholung
   erhalten. Große Kopfrotationen, Übersteuerung, Richtungswechsel und Zeitlimit
   verwerfen nur die aktuelle Bewegung, nicht die Satzkalibrierung. Dabei bleibt
   der Detektor bereit; ein erneuter 0,7-s-Halt ist nicht nötig. Datenlücken,
   Pausen und Moduswechsel setzen weiterhin die Kalibrierung zurück.

Die Schwellwerte sind Heuristiken. Insbesondere der Positionsproxy mit 0,025 m
Mindestamplitude ist keine gemessene anatomische Tiefe. Bei nur geringer
Beschleunigung kann ein IMU-Detektor Stillstand nicht sicher von konstanter
Geschwindigkeit unterscheiden. Ein kurzer Halt in der oberen Position hilft
bei der Bestätigung der letzten Wiederholung.

## Evaluation und Grenzen

- 0 Versuchspersonen, keine Hardware-Aufnahmen; ausschließlich synthetische Signale.
- Ursprünglich 38 Regressionstests in `open_wearable/test/apps/activity_tracker/push_up_detector_test.dart`.
- Unabhängige quintische Ruhe-zu-Ruhe-Trajektorien liefern die Referenz: jeweils
  6 Zyklen bei 8/16/25 cm simuliertem Hub und 1/1,8/3/5/7 s Zyklusdauer, 100 Hz.
  In diesen 15 Signalen wurden vorher 82 von 90, jetzt 90 von 90 Zyklen gezählt.
- Weitere Fälle: 50/100/200 Hz, Halten oben/unten, Teilrückkehr, flache Bewegungen,
  Zeitüberschreitung, Kopfrotation, Clipping, Datenlücke, Moduswechsel, andere
  feste Sensororientierung, konstante Restoffsets und reproduzierbares Rauschen.
- Die drei Rauschtests verwenden gleichverteilte, unabhängige Störungen bis
  ±0,02/0,05/0,1 m/s² bei 100 Hz und festem Zufallsseed; kein Modell realer Störsignale.

Das ist ein Implementierungsvergleich, kein Nachweis nutzerübergreifender
Genauigkeit. Nächster Schritt: synchronisierte Earable-/Video-Aufnahmen mit
mehreren Personen, Tempi, Kopfhaltungen und Negativkontrollen; Parameter nur auf
Entwicklungspersonen abstimmen, anschließend getrennte Testpersonen auswerten.

Ausführen aus `open_wearable/`:

```sh
flutter test test/apps/activity_tracker/push_up_detector_test.dart
```

## Anpassung nach erstem Praxistest am 10.11.2026

Rückmeldung: Wiederholungen werden teilweise erkannt, danach erscheint wieder
„Hold the start position“; kleinere Bewegungen gehen verloren. Es liegen dazu
keine Rohdaten oder annotierten Referenzzahlen vor.

Ursache im Code: Auch lokale Bewegungsabbrüche riefen den vollständigen Reset
mit 0,7-s-Startpositions-Halt auf. Jetzt bleibt eine einmal erreichte
Satzkalibrierung bei solchen Abbrüchen erhalten. Eine übersteuerte Probe wird
verworfen und ihr Filter-Nachlauf entfernt. Echte Datenunterbrechungen bleiben
separat abgesichert.

Sensitivität: Mindesthub des Bewegungsproxys 0,035 → 0,025 m,
Absenkgeschwindigkeit 0,035 → 0,020 m/s, Rückkehrbeginn 0,025 → 0,015 m/s,
Rückkehranteil 80 → 75 %, Mindestdauer 0,65 → 0,50 s. Der obere Umkehrpunkt
verwendet maximal 0,04 m/s beziehungsweise 30 % des Rückkehr-Spitzenwerts und
erkennt einen Vorzeichenwechsel der Geschwindigkeit. Die aktive
Stillstandskorrektur greift erst unter 0,005 m/s, damit langsame Bewegungen
nicht fälschlich auf null gesetzt werden. Die Schwellwerte sind vorläufig.

Neue Gegenproben: 8 nahtlose Zyklen mit 4 cm simuliertem Hub bei 2/3/5 s,
Rotations-/Clipping-Störungen ohne erneuten Halt, Teilrückkehr mit Umkehr sowie
ungleiche Absenk-/Aufrichtzeiten. Vor der Änderung fehlten alle 8 langsamen
4-cm-Zyklen sowie die direkt auf die Störung folgenden Wiederholungen in den
entsprechenden Tests. Die ursprünglichen Teilbewegungs- und Negativtests bleiben
erhalten. Es ist weiterhin keine Aussage über reale Zählgenauigkeit möglich.

Prüfung nach der Anpassung: 46 Push-up-Tests und 213 Tests insgesamt bestanden;
`flutter analyze` ohne Befund. Die bisherigen Negativfälle bleiben grün.

## Leichte Sensitivitätsanpassung am 10.11.2026

Auf erneute Praxisrückmeldung: Absenkschwelle von 0,020 auf 0,019 m/s und
Beginn der Rückbewegung von 0,015 auf 0,013 m/s gesenkt. Mindesthub,
Rückwegvergleich, Mindestdauer und Gyroskop-Grenze bleiben unverändert.
Eine stärkere Absenkung des Mindesthubs wurde verworfen, weil dann eine
Teilbewegungs-Gegenprobe fälschlich zählte. Nur vorhandene Push-up-Tests und lokaler
Replay wurden erneut ausgeführt; keine neue vollständige Evaluationsrunde.
