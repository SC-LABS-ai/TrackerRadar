# TrackerRadar Alpha – Status

Stand: 2026-08-02, 23:08 Uhr Europe/Berlin

## Ergebnis

TrackerRadar 0.2.0-alpha ist als portable Windows-App lauffähig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Betriebsart: lokal, read-only
- Cloud/Telemetrie: keine
- Zusätzliche Runtime: keine Installation notwendig

## Verifizierte Funktionen

- WPF-Oberfläche startet fehlerfrei
- Aktive externe TCP-Verbindungen werden erkannt
- Verbindungen werden Prozess, PID, Ziel-IP, Port und Programmpfad zugeordnet
- Autostarts werden aus Registry und Startup-Ordnern gelesen
- Auffällige Script-Hosts und ungewöhnliche Ausführungspfade werden bewertet
- Befunde werden gebündelt angezeigt
- JSON-Bericht wird lokal erzeugt
- Automatische Aktualisierung alle 20 Sekunden
- Doppelklick-Details für Aktivitäten und Befunde

## Letzter Test

- Selbsttest: PASS
- GUI-Start: PASS
- GUI-Fehlerausgabe: leer
- Working Set nach 10 Sekunden: 162,8 MB
- Privater Speicher nach 10 Sekunden: 148,8 MB
- CPU-Zeit nach 10 Sekunden: 1,59 Sekunden
- Live-Scan: zuletzt rund 0,4 Sekunden

## Bewertung

Die Alpha ist für die manuelle Endnutzerprüfung geeignet. Der private Speicher erfüllt das Ziel von ungefähr 150 MB; der Working Set liegt etwas darüber, aber deutlich unter der ersten Version mit etwa 196 MB.

## Noch nicht enthalten

- Vollständige Datei-Leseüberwachung mit Prozesszuordnung
- Aktive Firewall-Blockierung
- Deaktivieren oder Entfernen von Autostarts
- Windows-Hardening und Rollback
- Signierter Installer
- Hintergrunddienst oder eigener Treiber

Diese Punkte werden erst nach der Nutzerprüfung priorisiert, damit das Produkt schlank bleibt und nicht überentwickelt wird.
