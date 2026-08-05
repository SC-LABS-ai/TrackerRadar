# TrackerRadar Alpha - Status

Stand: 2026-08-05, 17:16 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.5-alpha` ist als portable, lokale Windows-Anwendung fuer die interne Alpha-Nutzung fertiggestellt. Der aktuelle Pass haertet ausschliesslich die bestaetigungspflichtige Firewall-Steuerung und ihre Ruecknahme. Netzwerkmonitoring, Datei-/Ordnerzugriff, Autostart, History, Findings, Sprache, Branding und Launcher wurden nicht funktional umgebaut.

## Sicherer Blockieren-/Freigeben-Ablauf

- Der Activities-Button ist ohne gueltige Auswahl deaktiviert.
- Nach Auswahl einer App liest TrackerRadar zuerst den exakten Zustand seiner deterministischen Windows-Firewall-Regel.
- Ohne Regel erscheint `Internetzugriff blockieren` beziehungsweise `Block internet access`.
- Mit exakter TrackerRadar-Regel und passendem angewendetem Change-Vault-Eintrag erscheint `Internetzugriff freigeben` beziehungsweise `Restore internet access`.
- Eine Regel ohne passenden sicheren Change-Vault-Eintrag wird nicht automatisch entfernt.
- Nach einem fehlgeschlagenen Blockversuch wird der Regelzustand erneut gelesen. Wenn keine bestaetigte Regel existiert, meldet TrackerRadar ausdruecklich, dass nichts geaendert wurde und keine Ruecknahme erforderlich ist.
- Der erhoehte Helper wartet begrenzt auf seine lokalen Pointer- und Request-Dateien, um kurzzeitige `nicht gefunden`-Fehler nach der UAC-Bestaetigung zu vermeiden.

## Wispr-Flow-Pruefung

Die vom Nutzer gemeldete Aktion wurde ausschliesslich read-only untersucht:

- Wispr-Flow-Programmpfad vorhanden: **PASS**
- Wispr Flow aktuell aktiv: **PASS**
- TrackerRadar-Firewall-Regel fuer Wispr Flow: **nicht vorhanden**
- sonstige Wispr-Firewall-Regel: **nicht vorhanden**
- Change-Vault-Eintrag: **nicht vorhanden**
- aktueller Zustand: **Wispr Flow ist nicht blockiert**

Bei der initialen Wispr-Flow-Diagnose wurde keine reale Firewall-Regel angelegt oder entfernt. Der separate isolierte `curl.exe`-Test hat danach eine ausschliesslich fuer die Testkopie geltende Regel erfolgreich angelegt, die Verbindung zu drei neutralen HTTPS-Zielen blockiert und die Regel anschliessend vollstaendig entfernt.

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper inklusive read-only Blockstatus: **10/10 PASS**
- Control-UAC-Wrapper: **PASS**
- isolierter Firewall-Block-/Freigabe-Test mit kopierter `curl.exe`: **PASS**
- Regel erstellt und verifiziert, drei von drei Testzielen blockiert, doppelte Regel verhindert, Regel entfernt, drei von drei Testzielen wieder erreichbar, keine Restregel: **PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **PASS**
- Lokalisierung, Unicode und Speicherung: **8/8 PASS**
- deutsche und englische Sprachschluessel: **153/153**
- versteckter Launcher und sichtbares App-Fenster: **PASS**
- sechs Ansichten, beide Sprachen und Safe-Control-Zustaende: **38/38 PASS**
- GUI-Fehlerausgabe: leer

## Letzter vollstaendiger Regressionstest

- Working Set nach 10 Sekunden: **179,6 MB**
- privater Speicher nach 10 Sekunden: **159,9 MB**
- CPU-Zeit nach 10 Sekunden: **4,14 Sekunden**
- Ziel unter 180 MB Working Set: **PASS**
- Ziel unter 200 MB Working Set: **PASS**

## Portable-Paket

Das finale Paket wird durch `Build-Portable.ps1` nur erzeugt, wenn App, Control, UAC-Wrapper, Dateizugriff, Lokalisierung, Launcher und UI-Gates bestehen. Die separate SHA-256-Datei ist die verbindliche Hashquelle fuer das erzeugte ZIP.

## Verbleibende oeffentliche Haertungsaufgaben

- Portable-Paket auf einem zweiten Windows-PC testen
- Rechte an Marken- und Bildassets abschliessend dokumentieren
- aktuelle Screenshots von `0.5.5-alpha` erstellen
- GitHub Private Vulnerability Reporting aktivieren

## Bewertung

TrackerRadar `0.5.5-alpha` beseitigt die unklare Situation nach einem fehlgeschlagenen Blockversuch: Der Nutzer sieht den bestaetigten Regelzustand und erhaelt eine Freigabeoption nur fuer sicher zuordenbare TrackerRadar-Aenderungen. Der reale isolierte Firewall-Wirkungstest ist bestanden. Das oeffentliche Repository ist unter `https://github.com/SC-LABS-ai/TrackerRadar` eingerichtet; verbleibend sind der zweite Windows-PC, die Asset-Rechte, aktuelle Screenshots und die Website-Aktualisierung.
