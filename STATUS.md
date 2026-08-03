# TrackerRadar Alpha - Status

Stand: 2026-08-03, 14:03 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.4.0-alpha` ist als portable, lokale Windows-App mit bewusst begrenzten und reversiblen Safe-Control-Funktionen lauffaehig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Monitoring: lokal ohne dauerhafte Administratorrechte
- Aenderungen: nur nach Bestaetigung; geschuetzte Aktionen mit sichtbarem Windows-UAC-Dialog
- Cloud/Telemetrie: keine
- Zusaetzliche Runtime: keine Installation notwendig

## Neu in 0.4

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
- Control-Helper: **8/8 PASS**
- UI-Navigation: **5/5 PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer
- File-Startup deaktivieren und rueckgaengig machen: **PASS**
- Registry-Startup deaktivieren und rueckgaengig machen: **PASS**
- Registry-`ExpandString`-Typ unveraendert wiederhergestellt: **PASS**
- Lokale Request/Response-Schnittstelle: **PASS**
- Testdaten nach Pruefung bereinigt; Change Vault startet leer

## Letzter Regressionstest

- Working Set nach 10 Sekunden: **185,7 MB**
- Privater Speicher nach 10 Sekunden: **168,6 MB**
- CPU-Zeit nach 10 Sekunden: **2,33 Sekunden**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.4.0-alpha-portable.zip`
- Groesse: **211.176 Bytes**
- SHA-256: `9D6C5C8A0536B2A707462552C4338FC597663BBC5BCFCEF7839F7A7ED7AFE117`
- Build-Gates: Monitoring **8/8**, Control **8/8**, Navigation **5/5**

## Noch manuell zu pruefen

Die echte Firewall-Regel wird in automatisierten Tests bewusst nicht auf dem Produktivsystem angelegt. Vor einer oeffentlichen Alpha ist ein manueller UAC-Test erforderlich:

1. harmlose Testanwendung auswaehlen,
2. ausgehende Regel anlegen,
3. Regel und Wirkung pruefen,
4. ueber Change Vault zuruecknehmen,
5. vollstaendige Entfernung der Regel bestaetigen.

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