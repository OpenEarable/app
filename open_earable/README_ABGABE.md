# Wichtige Infos zur Abgabe
Hier finden sich einige wichtige Infos zur Abgabe und der Inbetriebnahme der App.

## iOS Deployment und App-ID
1. Das Installieren auf dem iPhone war mit "edu.kit.teco.openearable" als App-ID nicht möglich. Ich habe es daher hier zu "ekulos.edu.kit.teco.openearable" geändert, dies muss beim Testen berücksichtigt werden.
2. Ohne Developer-Account war auch der Zugriff auf den Notifications-Dienst nicht möglich. Ich musste diesen entfernen.

## Funktionalität
1. Die vollständige Funktionalität wurde lediglich auf einem iPhone überprüft. Ein Android-Gerät stand nicht zur Verfügung.
2. In iOS und Android-Simulatoren lief die Anwendung korrekt, die IMU-Earable-Funktionalität konnte mangels Verbindung zum Earable nicht getestet werden.
3. Der Schrittzähler wurde über simples Joggen am Platz getestet. Leichtes auf und ab bewegen des Earables funktioniert genauso.
4. Die App wurde lediglich mit der IMU-Frequenz von 30 Hz entwickelt, bitte diese auch zum Testen verwenden.

## AndroidManifest.xml und Info.plist
In beiden dieser Dateien wurden Änderungen vorgenommen, sodass die App auf die Callbacks von Spotify aus dem Browser reagieren kann.

## Spotify Zugang
1. Zur Verwendung dieser App wird ein Spotify Premium Konto benötigt, da sonst keine App im Developer-Portal erstellt werden kann. Sollte dies ein Problem darstellen, schreiben sie mir bitte eine Mail.
2. Falls ein Spotify Premium Konto vorliegt, muss im Developer-Portal eine App erstellt werden: https://developer.spotify.com/dashboard
3. Diese App MUSS als Redirect URI den folgenden Wert besitzen, andernfalls wird die Verbindung zur App nicht funktionieren: ekulos-edu-kit-teco-openearable-rythmrunner://callback/
4. Unter dem Reiter "APIs Used" habe ich Web API, iOS, Web Playback SDK und Android ausgewählt.
5. Sobald die App korrekt erstellt wurde, kann man über den "Settings" Knopf auf der App-Übersicht eine Client-ID und einen Client-Secret abrufen. Diese beiden Werte müssen in der App über den Knopf "Change Spotify settings" in der Spotify Karte eingetragen werden.
6. Sollte es beim Einrichten der App zu Problemen kommen, schreiben sie mit bitte eine Mail.

## Spotify Player Probleme
Auf Mobilen Geräten funktioniert die Web-API zum Starten von Musik nur, wenn das Gerät kurz zuvor aktiv war. Startet keine Musik und es erscheint eine Fehlermeldung, muss die Spotify-App auf dem Handy lediglich einmal geöffnet und Musik gestartet werden, danach kann in der Ryhtm Runner App das Gerät über die Refresh Funktionalität in der Spotify-Karte wieder ausgewählt und verwendet werden.

## Step-Tracker Settings
1. Die App verwendet zum Tracken der Schritte mehrere Thresholds. Diese können in der Step Counter Settings Karte angepasst werden. Je niedriger die Werte sind, desto empfindlicher ist der Tracker. Die voreingestellten Werte haben sich während der Entwicklung bewährt, es ergibt jedoch durchaus Sinn zu prüfen, ob die Schrittzahl möglichst korrekt ist.
2. Es empfiehlt sich Anpassungen symmetrisch vorzunehmen, das heißt eine Verringerung des X-Thresholds um 0.5 sollte im Idealfall auch eine Verringerung für den Z-Threshold bedeuten.
