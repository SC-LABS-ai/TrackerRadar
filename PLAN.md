# TrackerRadar Alpha – verbindlicher schlanker Plan

## Produktentscheidung

TrackerRadar Alpha wird zunächst als portable, lokale Windows-App umgesetzt.

- Oberfläche: native WPF-Oberfläche im SC-LABS-Stil
- Laufzeit: vorhandenes Windows PowerShell 5.1 und .NET Desktop Runtime
- Installation: für Alpha nicht erforderlich
- Start: Doppelklick auf `Start-TrackerRadar.cmd`
- Daten: ausschließlich lokal im Projektordner
- Telemetrie/Cloud: keine
- Administration: Read-only-Betrieb ohne Administratorrechte

## Warum zunächst ohne Installer

Ein Installer würde in der ersten Iteration zusätzliche Arbeit für Signierung, Aktualisierung, Deinstallation, erhöhte Rechte und Paketpflege verursachen. Die portable Alpha kann direkt geprüft werden. Nach erfolgreichem Funktions- und UX-Test wird daraus ein kleiner Installer gebaut.

## Alpha-Funktionsumfang

1. Aktive externe TCP-Verbindungen nach Anwendung anzeigen.
2. Zieladresse, Zielport, Prozess, PID und Programmpfad zuordnen.
3. Prozesse aus Temp-/Download- oder ungewöhnlichen Pfaden hervorheben.
4. Script-Hosts mit externen Verbindungen hervorheben.
5. Autostarts erfassen und auffällige Einträge melden.
6. Digitale Signatur ausgewählter auffälliger Programme prüfen.
7. Wenige, gebündelte Befunde statt Ereignisflut anzeigen.
8. Manuelles Sofort-Scannen und schonende automatische Aktualisierung.
9. Lokalen JSON-Scanbericht erzeugen.
10. Selbsttest und Ressourcenmessung bereitstellen.

## Bewusste Grenzen der Alpha

- Kein eigener Kernel-Treiber.
- Kein TLS-Aufbrechen und kein Root-Zertifikat.
- Keine Inhaltsanalyse persönlicher Dateien.
- Keine vollständige Erkennung von Lesezugriffen auf beliebige Dateien.
- Keine automatischen Löschungen oder Windows-Debloat-Aktionen.
- Noch keine aktive Blockierung; zunächst verlässliche Read-only-Erkennung.

Datei-Lesezugriffe benötigen für eine zuverlässige Zuordnung später ETW-/Minifilter- oder Audit-Technik. In der Alpha werden deshalb Netzwerk, Prozesse, Autostarts und auffällige Ausführungspfade zuverlässig priorisiert, ohne falsche Vollständigkeit zu behaupten.

## Qualitätsziele

- Leerlauf-RAM möglichst unter 150 MB auf dem Zielsystem.
- Scanintervall mindestens 8 Sekunden.
- Maximal 25 Aktivitäten und 8 Befunde gleichzeitig in der Übersicht.
- Kein dauerhaftes CPU-Polling.
- Keine Netzwerkverbindung durch TrackerRadar selbst.
- Verständliche Sprache ohne SOC-/Firewall-Fachjargon.

## Prüf- und Verbesserungsloop

1. Syntax- und Selbsttest.
2. Live-Snapshot auf der Workstation.
3. GUI-Starttest.
4. CPU-/RAM-Messung.
5. Scanbericht auf Plausibilität prüfen.
6. Fehler und unnötige Last korrigieren.
7. Tests erneut ausführen.
8. Ergebnis und bekannte Grenzen dokumentieren.

## Nächste Produktstufe nach Nutzerprüfung

Nur nach erfolgreicher Alpha-Prüfung:

- Internetzugriff pro App über Windows Firewall blockieren.
- Autostart sicher deaktivieren und zurücknehmen.
- Schutz ausgewählter sensibler Ordner erweitern.
- Signierter Installer und saubere Deinstallation.
