# TrackerRadar Alpha – Status

Stand: 2026-08-03, 10:51 Uhr Europe/Berlin

## Ergebnis

TrackerRadar 0.2.2-alpha ist als portable Windows-App lauffähig und wurde mit einem vollständigen UI-Konsistenzpass für Logos, Karten, Navigation und Buttons überarbeitet.

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
- Working Set nach 10 Sekunden: 177,2 MB
- Privater Speicher nach 10 Sekunden: 159,8 MB
- CPU-Zeit nach 10 Sekunden: 1,89 Sekunden
- Live-Scan: zuletzt rund 0,4 Sekunden
- Markenassets: optimierte PNG-Dateien, zusammen etwa 111 KB

## Bewertung

Die Alpha ist für die manuelle Endnutzerprüfung geeignet. Mit den echten Markenassets liegt der private Speicher bei rund 160 MB und damit weiterhin innerhalb des bewusst schlanken Alpha-Ziels. Eine spätere kompilierte Version wird separat bewertet; dafür werden noch keine Leistungsversprechen gemacht.

## Noch nicht enthalten

- Vollständige Datei-Leseüberwachung mit Prozesszuordnung
- Aktive Firewall-Blockierung
- Deaktivieren oder Entfernen von Autostarts
- Windows-Hardening und Rollback
- Signierter Installer
- Hintergrunddienst oder eigener Treiber

Diese Punkte werden erst nach der Nutzerprüfung priorisiert, damit das Produkt schlank bleibt und nicht überentwickelt wird.
