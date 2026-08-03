# TrackerRadar Alpha - Status

Stand: 2026-08-03, 16:36 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.4.1-alpha` ist als portable, lokale Windows-App mit bewusst begrenzten und reversiblen Safe-Control-Funktionen lauffaehig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Monitoring: lokal ohne dauerhafte Administratorrechte
- Aenderungen: nur nach Bestaetigung; geschuetzte Aktionen mit sichtbarem Windows-UAC-Dialog
- Cloud/Telemetrie: keine
- Zusaetzliche Runtime: keine Installation notwendig

## Neu in 0.4.1

- Doppelte TrackerRadar-Firewall-Regeln werden vor dem Anlegen erkannt
- Exakte Programmregel wird nach dem Anlegen verifiziert
- Regelentfernung wird nach dem Undo verifiziert
- Abgebrochene oder nicht bestaetigte UAC-Abfragen werden als unveraenderter Zustand gemeldet
- Separater, lokal begrenzter UAC-Wrapper mit eigener Selbstpruefung
- Isolierter Firewall-Test mit kopierter Windows-`curl.exe` vorbereitet

## Seit 0.4 enthalten

- Internetzugriff einer ausgewaehlten Anwendung ueber eine ausgehende Windows-Firewall-Regel blockieren
- Ausgewaehlte neue, geaenderte oder auffaellige Autostarts deaktivieren
- Lokaler Change Vault mit Zeit, Aktion, Ziel und Status
- Ruecknahme unterstuetzter Firewall-, Registry- und Startup-Ordner-Aenderungen
- Separater lokaler Control-Helper ohne offenen Port und ohne dauerhafte Elevation
- Fuenfte Ansicht `Aenderungen`
- Change-Datensatz wird vor dem Eingriff als `Pending` geschrieben
- Registry-Werttyp wird fuer exakte Ruecknahme gespeichert

## Sicherheitsgrenzen

- Keine automatische Blockierung oder Bereinigung
- Keine Loeschung unbekannter Dateien
- Keine Entfernung von Windows-Komponenten
- Keine dauerhafte Admin-App und kein neuer Windows-Dienst
- Firewall-Aktion betrifft nur ausgehenden Verkehr der ausgewaehlten EXE
- Autostart wird deaktiviert, nicht vernichtet; Originalwert oder Originaldatei bleibt im Change Vault wiederherstellbar

## Verifizierte Funktionen

- Monitoring-Kern: **8/8 PASS**
- Control-Helper: **9/9 PASS**
- UAC-Wrapper: **3/3 PASS**
- UI-Navigation: **5/5 PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer
- File-Startup deaktivieren und rueckgaengig machen: **PASS**
- Registry-Startup deaktivieren und rueckgaengig machen: **PASS**
- Registry-`ExpandString`-Typ unveraendert wiederhergestellt: **PASS**
- Lokale Request/Response-Schnittstelle: **PASS**
- Testdaten nach Pruefung bereinigt; Change Vault startet leer

## Letzter Regressionstest

- Working Set nach 10 Sekunden: **185,5 MB**
- Privater Speicher nach 10 Sekunden: **167,1 MB**
- CPU-Zeit nach 10 Sekunden: **2,66 Sekunden**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.4.1-alpha-portable.zip`
- Groesse: **215.967 Bytes**
- SHA-256: `E75FB0F50FFE815B848B641ADB5DFBFFBE41F1575ED2051AA8EA082D087372B9`
- Build-Gates: Monitoring **8/8**, Control **9/9**, UAC-Wrapper **3/3**, Navigation **5/5**

## Noch manuell zu pruefen

Der isolierte Test verwendet ausschliesslich eine Kopie von Windows-`curl.exe` unter `data/firewall-test`. Mehrere Teststarts wurden vor der Regelanlage beendet, weil die sichtbare Windows-UAC-Abfrage nicht bestaetigt wurde. TrackerRadar meldete korrekt, dass nichts geaendert wurde. Danach wurden jeweils bestaetigt:

- keine Testregel vorhanden,
- kein Change-Vault-Eintrag vorhanden,
- keine Test-EXE aktiv.

Vor einer oeffentlichen Alpha bleibt ein einmalig bestaetigter Block/Undo-Lauf erforderlich:

1. erste UAC-Abfrage fuer die isolierte Testregel bestaetigen,
2. Blockwirkung pruefen,
3. zweite UAC-Abfrage fuer Undo bestaetigen,
4. Wiederherstellung und fehlende Restregel bestaetigen.

## Bewertung

Version 0.4 liefert die ersten echten Schutzaktionen, ohne TrackerRadar in eine schwere Security-Suite zu verwandeln. Gegenueber 0.3 steigt der private Speicher nur geringfuegig. Die Anwendung bleibt ohne Electron, Datenbank, Cloud, Hintergrunddienst oder eigenen Treiber.

## Weiterhin nicht enthalten

- Vollstaendige Datei-Leseueberwachung mit Prozesszuordnung
- Kontrolle beliebiger vorhandener Autostarts ausserhalb eines Befunds
- Automatische Tracker-Blocklisten
- Windows-Hardening-Profile
- Signierter Installer
- Hintergrunddienst oder eigener Treiber
- Schutzversprechen gegen jede Malware oder Backdoor