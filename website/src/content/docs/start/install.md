---
title: Installation
description: setDING auf Android, Windows und Linux installieren.
sidebar:
  order: 2
---

Alle Versionen findest du bei den
[Releases auf GitHub](https://github.com/tafli/setDING/releases/latest).

## Android

setDING wird über [Obtainium](https://github.com/ImranR98/Obtainium) installiert
und aktuell gehalten. Die App läuft auf 64-Bit-ARM-Geräten (arm64), also auf
praktisch allen aktuellen Tablets.

1. Installiere Obtainium (aus seinen GitHub-Releases oder aus F-Droid).
2. Tippe in Obtainium auf **Add app**, gib `https://github.com/tafli/setDING` ein
   und tippe auf **Add**.
3. Installiere setDING. Obtainium meldet neue Versionen und bietet das Update an.

## Windows

1. Lade `setding-<Version>-windows-x64-setup.exe` herunter und starte die Datei.
   Sie installiert setDING für deinen Windows-Benutzer, ohne Administratorrechte.
2. Die App ist nicht signiert, deshalb warnt Windows SmartScreen einmal; klicke
   auf **Weitere Informationen** und dann auf **Trotzdem ausführen**.

Ist eine neue Version verfügbar (siehe [Updates](#updates)), bietet setDING im
Hinweis und unter **Einstellungen → Speicher & Info** **Installieren** an. Das lädt
sie herunter, schliesst setDING, aktualisiert die App und startet sie wieder;
deine Daten bleiben erhalten. Eine neuere Setup-Datei von Hand
zu starten, bewirkt dasselbe.

Lieber ohne Installation? `setding-<Version>-windows-x64.zip` enthält dieselbe
App: entpacken und `setding.exe` starten. Diese Kopie aktualisiert sich nicht
selbst.

## Linux

1. Lade `setding-<Version>-linux-x64.AppImage` herunter.
2. Mach die Datei ausführbar (im Dateimanager unter *Eigenschaften* oder mit
   `chmod +x setding-*.AppImage`) und starte sie.

Ist eine neue Version verfügbar (siehe [Updates](#updates)), bietet setDING
**Installieren** an. Die App lädt das neue AppImage herunter, ersetzt die Datei,
schliesst sich und startet neu; deine Daten bleiben erhalten. Die Datei muss dafür
in einem Ordner liegen, in den du schreiben darfst (z. B. in deinem Home-Ordner).
Startet das AppImage nicht, fehlt FUSE; installiere das Paket `fuse3` deiner
Distribution.

Lieber ohne AppImage? `setding-<Version>-linux-x64.tar.gz` enthält dieselbe App:
entpacken und `setding` starten. Diese Kopie aktualisiert sich nicht selbst.

## Updates

setDING prüft einmal am Tag, ob eine neuere Version verfügbar ist. Dann erscheint
ein Punkt bei **Einstellungen**, und unter **Einstellungen → Speicher & Info**
steht die neue Version mit einem Link zur Download-Seite (mit **Installieren**
unter Windows, wenn du setDING mit der Setup-Datei installiert hast, und beim
Linux-AppImage). Im
Live-Modus erscheint der Hinweis nie.

Nach einem Update zeigt setDING einmal kurz **Neu in setDING …**; **Anzeigen**
listet auf, was sich seit der zuvor genutzten Version geändert hat. Du kannst es
jederzeit unter **Einstellungen → Speicher & Info → Was ist neu** nachlesen.

## iOS

Folgt später.
