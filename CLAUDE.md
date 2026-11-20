# CLAUDE.md

Dieses Repo ist unser Team-Fork der OpenWearables-App für das **Praktikum Wearable Computing** (KIT, TECO, WS 2026/27). Wir sind Projektgruppe 4 und bauen **Earable Fitness Tracking**. Quelle für den Seminarteil: Intro-Folien vom 04.11.2026.

## Unser Projekt: Earable Fitness Tracking

**Ziel:** Ein Echtzeit-System für OpenEarable 2.0, das aus den Sensordaten am Ohr Schritte zählt, Übungen erkennt, Wiederholungen zählt und übungsbezogene Werte schätzt. Die Ergebnisse zeigt eine App dem Nutzer an.

**Aufgaben:**

1. **Schrittzähler:** robust und dauerhaft laufend auf IMU-Basis. Echte Schritte von Kopfbewegungen trennen. Vorverarbeitung, Peak-Detection und adaptive Schwellwerte untersuchen, mit verschiedenen Gehgeschwindigkeiten und Alltagsbewegungen testen.
2. **Übungen und Wiederholungen:** zuerst Kniebeugen und Liegestütze, später erweiterbar. Herausfinden, welche IMU-Features die Übungen gut beschreiben, und Algorithmen mit leichtgewichtigen ML-Klassifikatoren vergleichen.
3. **Sprunghöhe:** Sprünge erkennen und die Höhe aus der vertikalen Kopfbewegung schätzen. Genauigkeit gegen eine passende Referenzmessung prüfen.
4. **App-Integration:** Echtzeit-Feedback und Zusammenfassung von Schritten, Übungen, Wiederholungen und Sprunghöhe.
5. **Evaluation:** unter realistischen Bedingungen, über verschiedene Personen, Tempi und Ausführungsstile. Metriken: Schrittzahl-Fehler, Erkennungsgenauigkeit, Wiederholungsfehler, Sprunghöhen-Fehler.

**Bonus:** Übungen automatisch erkennen, Gehen, Laufen und Treppensteigen unterscheiden, multimodale Erkennung aus IMU und Mikrofon (z. B. Schrittgeräusche).

**Ausgangspunkt:** Die App gibt Zugriff auf alle Sensoren, eigene Apps laufen direkt in ihr, Audio ist über LE Audio verfügbar. Daten werden zum Smartphone gestreamt oder bei großen Mengen und Audio auf microSD geschrieben. Gerät, microSD und bei Bedarf ein Smartphone mit BLE 5.3 stellt der Lehrstuhl.

## Seminar: Rahmen und Bewertung

Gruppen aus 4 Personen: Problem verstehen, Lösung konzipieren, Prototyp bauen, iterieren, mit Nutzern testen, dokumentieren. Insgesamt sollen etwa 10–20 Personen an Datensammlung und/oder Evaluation teilnehmen. Das Ganze gilt als Vorstudie, auf der andere aufbauen können.

| Teil | Gewicht | Erwartung |
| --- | --- | --- |
| Zwischenpräsentation | unbenotet | ca. 10 min Vortrag, 10 min Diskussion |
| Abschlusspräsentation | **50 %** | 20 min inkl. Prototyp-Demo, 5 min Diskussion |
| Code | **25 %** | GitHub-Repo oder Zip, sorgfältig dokumentiert, gutes README, Abhängigkeiten festgehalten (`pubspec.yaml`, für Python `requirements.txt` oder `pyproject.toml`) |
| Paper | **25 %** | TECO-Overleaf-Vorlage, ca. 10–15 Seiten ohne Referenzen und Abbildungen, Abbildungen trotzdem einbauen |

**Aufbau des Papers:** kurze Einleitung, Related Work (ca. 1 Seite), Problem, Dokumentation der Lösung, Diskussion und Fazit. Andere sollen damit weiterarbeiten können.

### Termine

Pflichttermine sind fett. Q/A-Termine sonst freiwillig: mindestens 24 h vorher anmelden und etwas Praktisches zum Zeigen mitbringen (Stand, Fortschritt, Probleme).

| Datum | Termin |
| --- | --- |
| **11.11.2026** | **Q/A-Session (Pflicht), bis dahin zur Prüfung angemeldet sein** |
| 25.11., 09.12.2026 | Q/A |
| **16.12.2026** | **Zwischenpräsentation** |
| 13.01., 27.01., 10.02.2027 | Q/A |
| **17.02.2027** | **Abschlusspräsentation** |
| **31.03.2027, 23:59** | **Finale Abgabe** |

## Dokumentation ist Teil jeder Aufgabe

Präsentationen und Paper entstehen aus dieser Doku, deshalb wird sie **laufend** geschrieben und nicht erst am Ende:

- Jede nennenswerte Änderung, jedes Experiment und jede Entscheidung kommt im selben PR nach `docs/`. Aufbau siehe [docs/README.md](docs/README.md).
- Immer festhalten, **warum** etwas so gemacht wurde und welche Alternativen verworfen wurden.
- Messwerte nur mit Kontext: Personenzahl, Ablauf, Sensorrate, Referenzmessung, Datum.
- Abbildungen und Diagramme, die in Präsentation oder Paper taugen, unter `docs/figures/` ablegen und das Skript dazu mit einchecken.
- Claude denkt von sich aus daran und nennt am Ende einer Aufgabe, was dokumentiert wurde.
- Praktikumsdoku auf Deutsch, Code und Kommentare auf Englisch.

**Das Repo ist öffentlich:** keine Rohdaten von Probanden und keine personenbezogenen Daten einchecken, nur anonymisierte Ergebnisse.

## Repo-Überblick

- `open_wearable/`: die Flutter-App, hier läuft alles ab.
  - `lib/apps/`: In-App-Anwendungen. Neue App in `lib/apps/<name>/` anlegen und in `_apps` in `lib/apps/widgets/apps_page.dart` eintragen. `posture_tracker/` ist die Vorlage (`model/`, `view/`, `view_model/`).
  - `lib/view_models/`: übergreifender Zustand (Provider), `lib/router.dart`: Routen, `lib/main.dart`: Start.
  - `test/`: Tests, `docs/`: App-Doku von Upstream. Bei Architekturänderungen mitpflegen.
- `docs/`: unsere Praktikumsdoku.
- Sensorzugriff läuft über das Paket `open_earable_flutter`. Beispiel: `lib/apps/posture_tracker/model/earable_attitude_tracker.dart`.

## Entwickeln

Befehle aus `open_wearable/` heraus. Vor jedem PR müssen die letzten drei durchlaufen:

```bash
flutter pub get
flutter run
dart format lib test
flutter analyze
flutter test
```

- Ohne Hardware testen: `flutter run --dart-define=APP_STORE_PREVIEW=true`
- Flutter-Version steht in `open_wearable/.flutter_version`.
- **Windows:** Für `flutter pub get` muss der Entwicklermodus an sein (Symlinks für Plugins).
- **Android-Toolchain:** Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0. Java 25 braucht mindestens Gradle 9.1, Flutter 3.47 testet bis Gradle 9.3.1. Die CI baut mit Java 21. Hintergrund im [Journal](docs/journal.md).

## Git

- **`origin` ist unser Fork, `gh` zielt bei Forks aber standardmäßig auf Upstream.** PRs daher immer so erstellen:

  ```bash
  gh pr create --repo philgenb/openearable-activity-tracker --base main
  ```

- Nichts an `OpenEarable/app` schicken, außer das Team will das ausdrücklich.
- Regeln aus [CONTRIBUTING.md](CONTRIBUTING.md): eigener Branch pro Änderung, Conventional Commits, Rebase statt Merge, öffentliche APIs dokumentieren.
