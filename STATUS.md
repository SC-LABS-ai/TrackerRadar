# TrackerRadar Alpha – Status

Stand: 2026-08-03, 11:41 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.3.0-alpha` ist als portable, lokale und weiterhin vollständig read-only arbeitende Windows-App lauffähig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Betriebsart: lokal, read-only
- Cloud/Telemetrie: keine
- Zusätzliche Runtime: keine Installation notwendig

## Neu in 0.3

- Lokale Baseline für bekannte Verbindungen und Autostarts
- Erkennung neuer Verbindungen ohne wiederholte Falschmeldung bei jedem Scan
- Unterscheidung zwischen `Neu`, `Wieder aktiv`, `Aktiv` und `Baseline`
- Domainauflösung über den lokalen Windows-DNS-Cache
- Verständliche Anbieter- und Zweckhinweise für bekannte Dienste
- Erkennung neuer, geänderter und entfernter üblicher Autostarts
- Begrenzter lokaler Sieben-Tage-Verlauf als JSONL
- Verlaufsspeicherung nur bei Änderungen oder spätestens alle 15 Minuten
- Funktionierende Ansichten: Übersicht, Aktivitäten, Befunde und Verlauf
- Detaillierte Aktivitätsansicht mit Domain, Anbieter, Zweck, IP, Port, Pfad und erster Erkennung

## Verifizierte Funktionen

- Aktive externe TCP-Verbindungen werden Prozess und Programmpfad zugeordnet
- Lokale Baseline wird angelegt und fortgeführt
- Dieselbe bekannte Verbindung wird nicht erneut als neu gemeldet
- Neue Verbindung wurde im Test korrekt erkannt
- DNS-Ziel `api.anthropic.com` wurde korrekt als Anthropic/KI-Cloud-Dienst erklärt
- Autostarts werden aus Registry und Startup-Ordnern gelesen
- JSON-Bericht und begrenzter Verlauf werden lokal erzeugt
- Navigation schaltet jeweils exakt eine Ansicht sichtbar
- Automatische Aktualisierung alle 30 Sekunden

## Letzter Regressionstest

- Kern-Selbsttest: **8/8 PASS**
- UI-Navigation: **4/4 PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer
- Working Set nach 10 Sekunden: **183,4 MB**
- Privater Speicher nach 10 Sekunden: **167,3 MB**
- CPU-Zeit nach 10 Sekunden: **2,16 Sekunden**
- Live-Scan: zuletzt rund **0,6 Sekunden**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.3.0-alpha-portable.zip`
- Größe: 203.637 Bytes
- SHA-256: `262F255695F7591CD3CC3040911146D8E6A52AAB0819D70728F032049FD76BDB`

## Bewertung

Version 0.3 liefert deutlich mehr Endnutzen als die reine Momentaufnahme aus 0.2.2. Der private Speicher stieg durch vier echte Ansichten, Baseline und Verlauf um etwa 7–8 MB. Eine weitere Demontage der Oberfläche für wenige Megabyte wäre aktuell unverhältnismäßig. Die App bleibt ohne Electron, Datenbank, Hintergrunddienst oder Cloud bewusst schlank.

## Noch nicht enthalten

- Vollständige Datei-Leseüberwachung mit Prozesszuordnung
- Aktive Firewall-Blockierung
- Deaktivieren oder Entfernen von Autostarts
- Change Vault und Rollback
- Windows-Hardening
- Signierter Installer
- Hintergrunddienst oder eigener Treiber

Diese Funktionen bleiben für spätere, getrennte Sprints vorgesehen.
