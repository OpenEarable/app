# Kniebeugen: Entwicklung mit realen IMU-Aufnahmen

Stand: 17.11.2026. Manuell gewählter Squat-Modus, kein ML-Klassifikator.

## Wiederverwendung und Abgrenzung

Wie bei Liegestützen liefert `ActivityEngine` Kalibrierung, Gyro-gestützte
Schwerkraftrichtung, vertikale Projektion und kausale Tiefpassfilterung. Sensorquelle,
Controller, Satzverwaltung, Export und Übungsbildschirm werden wiederverwendet.
`SquatDetector` ersetzt den bisherigen privaten `_RepetitionDetector`; der
Liegestütz-Detektor und die Schwellen anderer Modi bleiben unverändert.

Der Entwicklungsbereich liegt unter `open_wearable/tool/squats/`: Manifest,
CSV-Replay und lokale, ignorierte Aufnahmen. Rohdaten aus `temp/` bleiben ebenfalls
ignoriert. Öffentlich dokumentiert werden nur aggregierte Ergebnisse.

## Datensatz: Reihenfolge ist Teil der Referenz

Die fünf Ordnernamen geben folgende Abfolgen vor:

| Aufnahme | Abfolge | Referenz-Kniebeugen |
| --- | --- | ---: |
| squat-01 | 10 Kniebeugen | 10 |
| squat-02 | 5 Kniebeugen → Gehen → 5 Kniebeugen | 10 |
| squat-03 | 5 Kniebeugen → Hinsetzen → 5 Kniebeugen | 10 |
| squat-04 | 5 Kniebeugen → 3 Liegestütze → 5 Kniebeugen | 10 |
| squat-05 | 5 Kniebeugen → Treppen/Gehen → 5 Kniebeugen → Hinsetzen → 5 Kniebeugen → 3 Liegestütze | 15 |

Die gesamte Aufnahme läuft im Squat-Modus. Fremdbewegungen sind Negativkontrollen,
nicht herausgefilterte Daten. Die Zählreferenz stammt ausschließlich aus den
Ordnernamen. Übergangszeitpunkte, Versuchspersonenzahl, Ausführungstempo,
Aufnahmedatum und synchronisierte Referenzvideos sind nicht angegeben. Der
17.11.2026 ist das Auswertungsdatum, nicht das behauptete Messdatum.
Beschleunigung: m/s²; Gyroskop: deg/s als explizite Annahme aus dem üblichen
OE2-Export, im Replay nach rad/s umgerechnet. Die Exportdateien enthalten keine
Einheitenmetadaten. Sensorrate ungefähr 99,9 Hz; die lange Aufnahme enthält zwei
Lücken über 120 ms.

## Entscheidung: Wann zählt eine Wiederholung?

1. Im Squat-Modus reicht ein stabiler 0,7-s-Start: Betrag nahe 1 g (±0,55 m/s²),
   Gyro unter 0,35 rad/s und Betragsspanne höchstens 0,45 m/s². Andere Modi behalten
   ihre 1,5-s-Kalibrierung. Damit werden kleine Kopfbewegungen toleriert, nicht
   beliebig bewegte Daten nachträglich als kalibriert ausgegeben.
2. Der Detektor speichert die anfängliche Schwerkraftrichtung als Haltungsreferenz.
   Starke Rotation (>1,2 rad/s) oder eine Abweichung von ungefähr 46° verwerfen
   die aktuelle Bewegung; die ursprüngliche Haltungsreferenz bleibt bestehen.
3. Gefilterte vertikale Beschleunigung wird kurzfristig integriert. Gedämpfte
   Geschwindigkeit (1,5 s) und Position (4 s) begrenzen Offsetdrift. Im ruhigen,
   inaktiven Zustand wird der Restoffset nachgeführt.
4. Absenken beginnt unter −0,06 m/s und −0,048 m Positionsproxy. Der Mindesthub
   ist 0,12 m; die Rückkehrphase beginnt über +0,04 m/s.
5. Die Position muss mindestens 70 % der Absenkung zurückkehren. Gezählt wird
   nahe dem oberen Geschwindigkeitsumkehrpunkt, frühestens nach 0,8 s und vor
   einem 6-s-Zeitlimit. Nach einem Halt verhindert eine separate ungedämpfte
   Referenz, dass Positionsdämpfung allein eine Teilrückkehr vervollständigt.
6. Übersteuerung und starke Bewegungen verwerfen nur den laufenden Zyklus.
   Pausen, Datenlücken, ungültige Daten und Moduswechsel setzen den Detektor
   vollständig zurück. Bestätigte Zählungen bleiben im Controller erhalten.

Mindesthub und Positionswerte sind **Bewegungsproxies**, keine gemessene
anatomische Tiefe oder Bewertung der Kniebeugentechnik. Die IMU am Ohr kann
Knie-/Hüftbewegung nicht direkt beobachten. Hinsetzen und Aufstehen ohne längeren
Halt können ähnlich aussehen; reine vertikale Kopfbewegungen ebenfalls.

Verworfen: rohe Y-Achse als universelle Vertikale (sensor-/haltungsabhängig),
Übernahme der empfindlichen Liegestütz-Schwellen (kleine Fremdbewegungen),
unbegrenzte doppelte Integration (Drift), automatische Übungsklassifikation oder
ML mit diesen fünf nicht zeitannotierten Aufnahmen (keine belastbare Grundlage).
Keine nachträgliche künstliche Startkalibrierung und keine Sonderbehandlung
anhand des Dateinamens.

## Messkriterien und Grenzen

Entwicklungsvergleich: erwartete und gezählte Wiederholungen, signierter und
absoluter Zählfehler pro Aufnahme sowie Kalibrierungsabdeckung und Ereigniszeiten.
Baseline des bisherigen Codes in obiger Reihenfolge: 0, 0, 4, 0, 7.
Drei Aufnahmen bestanden nie die bisherige Startkalibrierung.

**Gleiche Gesamtzahl ist kein Klassifikationsnachweis.** Fehlzählungen in
Negativabschnitten können ausgelassene Kniebeugen kompensieren. Ereignisbezogene
Precision/Recall, falsch positive Zählungen pro Fremdbewegung und Wiederholungsfehler
pro Satz benötigen unabhängig annotierte Zeitintervalle. Dieses Material dient
zur Entwicklung, nicht als unabhängiger Testdatensatz oder nutzerübergreifender
Genauigkeitsnachweis. Keine Parameter anhand von Dateinamen auswählen.

## Ergebnisse vom 17.11.2026

Vollständiges kausales Replay mit deg/s-Annahme, 20-ms-Gyrozuordnung und ohne
künstliche Startdaten; Ergebnisse unter
[`results.json`](../../open_wearable/tool/squats/results.json).

| Aufnahme | Soll | Bisher | Jetzt | Fehler jetzt | Erste Kalibrierung (s) | Kalibrierte Samples (%) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| squat-01 | 10 | 0 | 10 | 0 | 0,72 | 96,84 |
| squat-02 | 10 | 0 | 9 | −1 | 0,73 | 97,68 |
| squat-03 | 10 | 4 | 9 | −1 | 0,71 | 97,68 |
| squat-04 | 10 | 0 | 7 | −3 | 1,80 | 95,05 |
| squat-05 | 15 | 7 | 8 | −7 | 43,70 | 71,24 |

Summe: 43 Zählungen bei 55 laut Ordnernamen vorgegebenen Kniebeugen; vorher 11.
Mittlerer absoluter Gesamtzählfehler je Aufnahme: 2,4 statt 8,8. Das ist **keine
Recall- oder Genauigkeitsangabe**. Beim langen Ablauf fehlt die Kalibrierung bis
43,70 s; dort kann der kausale Detektor vorherige Bewegungen nicht zählen.
Auch spätere Bestätigungen können ohne Zeitannotation nicht sicher den
Kniebeugen statt Fremdbewegungen zugeordnet werden. Der Mischdatensatz zeigt
weiterhin erhebliche Zählfehler; robuste Fremdbewegungsabgrenzung ist nicht belegt.

102 gezielte Tests bestanden: 21 neue synthetische Kniebeugenfälle,
49 bestehende Liegestützfälle, 14 Engine-Fälle und 18 CSV-/Zuordnungsfälle.
Synthetische Fälle umfassen vollständige Zyklen, verschiedene Tempi/Raten,
andere Sensororientierung, kleine Kopfbewegungen, Teilrückkehr, Halten,
Rotation, Übersteuerung, Datenlücke, Pause und Moduswechsel. Keine BLE-/Hardware-
oder Videoverifikation durchgeführt.
Die sechs geänderten/neuen Dart-Dateien wurden formatiert und gezielt mit
`dart analyze` geprüft: keine Befunde. Keine vollständige App-Testsuite oder
plattformweite Buildprüfung ausgeführt.


## Reproduktion

Aus `open_wearable/`:

```sh
dart run tool/squats/replay.dart
flutter test test/apps/activity_tracker/squat_detector_test.dart test/apps/activity_tracker/activity_engine_test.dart test/apps/activity_tracker/push_up_detector_test.dart test/tool/squat_recordings_test.dart
```

Die lokalen Dateien und genaue Replay-Aufrufvarianten beschreibt
[`tool/squats/README.md`](../../open_wearable/tool/squats/README.md).
