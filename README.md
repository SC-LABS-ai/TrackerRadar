# TrackerRadar Alpha

TrackerRadar ist eine schlanke, lokale Windows-App im SC-LABS-Stil. Sie zeigt aktive externe Netzwerkverbindungen, ordnet sie laufenden Programmen zu und weist auf auffällige Ausführungspfade oder Autostarts hin.

## Start

Doppelklick auf:

`Start-TrackerRadar.cmd`

Es ist keine Installation erforderlich.

## Was die Alpha kann

- Aktive externe TCP-Verbindungen pro Anwendung anzeigen
- Prozess, PID, Ziel-IP, Zielport und Programmpfad zuordnen
- Script-Hosts und Programme aus ungewöhnlichen Ordnern hervorheben
- Autostarts aus Registry und Startup-Ordnern prüfen
- Wenige, gebündelte Befunde statt Warnungsflut anzeigen
- Lokalen JSON-Bericht unter `data\latest-scan.json` erzeugen
- Automatisch alle 20 Sekunden aktualisieren
- Vollständig lokal arbeiten, ohne Cloud oder eigene Telemetrie

## Was die Alpha bewusst noch nicht kann

- Datei-Lesezugriffe vollständig einem Prozess zuordnen
- HTTPS-Inhalte entschlüsseln
- Programme automatisch blockieren oder löschen
- Windows-Komponenten verändern
- Malware oder Backdoors garantiert erkennen

## Bedienung

- `Jetzt pruefen`: sofort neue Momentaufnahme erstellen
- Doppelklick auf eine Aktivität: technische Details anzeigen
- Doppelklick auf einen Befund: Begründung anzeigen
- `Lokalen Bericht oeffnen`: letzten JSON-Bericht im Explorer markieren

## Technische Entscheidung

Die Alpha ist portable und nutzt vorhandenes Windows PowerShell 5.1 sowie WPF. Dadurch werden keine zusätzlichen Frameworks oder Browser-Runtimes installiert. Nach erfolgreicher Nutzerprüfung kann daraus eine kompilierte und signierte Installer-Version entstehen.

## Tests

Automatischer Test:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-TrackerRadar-App.ps1`

Testergebnisse liegen im Ordner `data`.
