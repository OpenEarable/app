# Journal

Neueste Einträge oben. Format siehe [README](README.md#journal-eintrag).

## 2026-11-17: Kniebeugen mit fünf lokalen Mischaufnahmen entwickelt

**Was:** Liegestütz-Implementierung und gemeinsame IMU-Vorverarbeitung geprüft.
Eigener `SquatDetector` ersetzt den alten generischen Wiederholungsdetektor;
Übungsbildschirm, Sensorquelle, Controller und Export bleiben gemeinsam.
Lokaler Entwicklungsbereich `open_wearable/tool/squats/` mit Manifest, Replay
und anonymisierten Ergebnissen; Rohdaten unter `temp/` und `data/` ignoriert.

**Warum:** Der bisherige Startfilter kalibrierte drei Aufnahmen nie. Im
Squat-Modus wird nun ein stabiler 0,7-s-Betragsverlauf bei kleinen Kopfrotationen
zugelassen; andere Modi unverändert. Größerer Mindest-Bewegungsproxy,
Rückkehrprüfung und stehende Haltungsreferenz statt empfindlicher Push-up-
Schwellen. Dämpfung darf nach einem Halt keine vollständige Rückkehr vortäuschen.

**Referenz und Ergebnis:** Fünf Aufnahmen mit ungefähr 99,9 Hz während der
Übertragung; lange Mischaufnahme mit zwei Zeitlücken. Die Ordnernamen geben
geordnete Abfolgen von Kniebeugen, Gehen, Treppen, Hinsetzen und Liegestützen
und insgesamt 55 Kniebeugen vor. Keine Zeitannotation, Personenzahl und
Messdatum unbekannt. Gyro deg/s ist eine dokumentierte Exportannahme.
Replay zählt 43 statt 11; Gesamtzählfehler pro Aufnahme im Mittel 2,4 statt 8,8.
Keine Erkennungsgenauigkeit: Fremdbewegungszählungen können fehlende Kniebeugen
kompensieren. Die lange Aufnahme kalibriert erst nach 43,70 s und zählt 8/15.
102 gezielte Tests bestanden; keine neue Hardware-Messung.

**Grenzen:** Erhebliche Fehler im Mischablauf; Fremdbewegungsabgrenzung und
personenunabhängige Genauigkeit nicht belegt. Begründungen, verworfene Ansätze,
Metriken und Reproduktion im [Kniebeugenbericht](algorithmen/kniebeugen.md).

## 2026-11-10: Push-up-Erkennung leicht empfindlicher eingestellt

Absenkschwelle 0,020 → 0,019 m/s und Rückkehrbeginn 0,015 → 0,013 m/s.
Mindesthub, Rückwegprüfung und Mindestdauer bleiben bestehen. Auf Wunsch
nur die vorhandenen Push-up-Tests und den lokalen Replay erneut geprüft.
Rohdaten unter `data/` bleiben außerhalb des Commits.

## 2026-11-10: Lowering-Blockade anhand einer lokalen Aufnahme geprüft

**Befund:** Die lokale Aufnahme hat etwa 100 Hz und keine Zeitlücken über 120 ms.
Mit dem bisherigen Code werden 3 Wiederholungen gezählt; die qualitative
Selbstauskunft liegt bei ungefähr 5–7, eine Videoannotation fehlt.

**Änderung:** Gedämpfte Integratoren begrenzen Offsetdrift. Ein separater,
ungedämpfter Rückweg-Proxy schützt Teilbewegungen nach Pausen. Für kontinuierliche
Zyklen wird zusätzlich die Dauer und Stärke beider Bewegungsphasen verglichen.

**Ergebnis:** Replay zählt 6 Wiederholungen. Alle 49 Push-up-Tests und 216 Tests
insgesamt bestehen, einschließlich Teilrückkehr und neuer Offsetwechsel-Fälle.
Das ist ein Entwicklungsvergleich an einer einzelnen, nicht exakt annotierten
Aufnahme; keine unabhängige Genauigkeitsevaluation. Rohdaten bleiben lokal.

## 2026-11-10: Kontinuierliche Push-ups nach Praxisrückmeldung

**Was:** Lokale Bewegungsabbrüche behalten jetzt die Satzkalibrierung. Kein neuer
Startpositions-Halt nach verworfenen Zyklen, Kopfrotationen oder Clipping.
Kleinere Bewegungen werden sensitiver erkannt; Umkehrpunkt und Driftkorrektur
berücksichtigen langsame Bewegungen. Englische UI erklärt den einmaligen Halt.

**Warum:** Der vollständige Reset blockierte nach einer unsicheren Wiederholung
erneut für die Startposition. Nur die Stillhaltezeit zu verkürzen hätte die
Ursache nicht beseitigt. Echte Datenlücken und Pausen verlangen weiter eine
neue Kalibrierung. Parameter und Gegenproben im
[Algorithmusbericht](algorithmen/liegestuetze.md#anpassung-nach-erstem-praxistest-am-10112026).

**Evaluation:** Synthetische Regressionen für nahtlose kleinere Zyklen, Störungen,
Teilbewegungen und ungleiches Tempo. Keine neuen Probandenaufnahmen oder
quantitativen Hardware-Messungen; die Praxisrückmeldung ist qualitativ.
46 Push-up-Tests und 213 Tests insgesamt bestanden, `flutter analyze` ohne Befund.

**Offen:** Erneuter Test am Earable, danach anhand synchronisierter Referenzen
prüfen, ob die höhere Sensitivität zusätzliche Fehlzählungen erzeugt.

## 2026-11-10: Push-up-Zähler nach Rebase geprüft und korrigiert

**Was:** `feat/activity-tracker` auf `origin/main` rebased; neuere Android-Toolchain
bei einem Konflikt beibehalten. Weiterentwicklung auf `fix/pushup-tracker-review`.
Eigener Push-up-Detektor mit Startpositions-Offsetkorrektur, erhaltener Absenkung
bei Pausen und Abbruch bei starken Kopfrotationen. Squat-Algorithmus unverändert.

**Warum:** Die bisherige Integrationsdämpfung konnte eine kleine Rückbewegung nach
einer Pause als vollständige Wiederholung zählen. Stattdessen wird der Weg über
den kurzen Zyklus erhalten; Restgeschwindigkeit wird zwischen Zyklen nicht
künstlich zurückgesetzt. Details und verworfene Alternativen unter
[Liegestütz-Algorithmus](algorithmen/liegestuetze.md).

**Ergebnis:** 38 gezielte Regressionstests. In 15 idealen Signalen mit je 6 Zyklen,
100 Hz, 8/16/25 cm simuliertem Hub und 1–7 s Zyklusdauer: zuvor 82/90, jetzt 90/90
gezählte Wiederholungen. Eine Teilrückkehr von 2 cm nach 16 cm Absenken und 3 s
Pause zählt jetzt 0 statt 1. Personenzahl: 0, keine realen Messdaten.
`flutter analyze` ohne Befund; vollständige Testsuite: 205 bestanden;
Formatierungsprüfung der geänderten Dart-Dateien ohne Änderungen.

**Offen:** Hardware-/Nutzerevaluation, belastbare Parameter und Abgrenzung von
Kopfbewegungen gegenüber echten Körperzyklen. Kein Nachweis von Ausführungsqualität.

## 2026-11-06: Android-Build auf Java 25 umgestellt

**Was:** Gradle von 8.14 auf 9.3.1 aktualisiert, AGP von 8.12.1 auf 9.1.0, Kotlin von 2.2.21 auf 2.4.0.

**Warum:** Der Build brach unter Java 25 ab, weil Gradle das erst ab Version 9.1 unterstützt. Wir nehmen 9.3.1 statt einer neueren Version, weil das die höchste ist, die Flutter 3.47 kennt. AGP und Kotlin entsprechen der Vorlage von Flutter 3.47. Die Alternative, lokal ein älteres JDK zu installieren und per `flutter config --jdk-dir` einzustellen, hätte jeder im Team einzeln machen müssen.

**Folgeänderungen, die dafür nötig waren:**

- `flutter_headset_detector` entfernt. Es nutzt `jcenter()`, das in Gradle 9 nicht mehr existiert, und es gibt keine neuere Version. Die App verwendete das Paket nirgends.
- `android.newDsl` und `android.builtInKotlin` auf `false` gesetzt, wie in der Flutter-Vorlage. Mit AGP 9 gehen sonst Flutter-Plugins kaputt.
- `proguard-android.txt` durch `proguard-android-optimize.txt` ersetzt, weil AGP 9 die alte Datei ablehnt. Mit `-dontoptimize` in `proguard-rules.pro` bleibt das Verhalten der Release-App wie bisher.

**Ergebnis:** Mit Java 25.0.3 und Flutter 3.47.6 laufen Debug- und Release-APK durch, `flutter analyze` ist sauber und alle 142 Tests bestehen.

**Offen:**

- Noch nicht auf einem echten Gerät ausprobiert.
- `ios/Podfile.lock` wurde von Hand angepasst, weil unter Windows kein `pod install` läuft.
- `-dontoptimize` kann raus, sobald ein Release-Build mit R8-Optimierung auf einem Gerät getestet wurde.
- Flutter warnt, dass künftige Versionen Plugins mit eigenem Kotlin-Plugin nicht mehr bauen (`flutter_archive`, `mcumgr_flutter`). Das betrifft uns erst beim nächsten Flutter-Update.
