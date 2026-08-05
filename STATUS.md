# TrackerRadar Alpha - Status

Stand: 2026-08-05, 15:05 Uhr Europe/Berlin

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

Bei dieser Diagnose und beim 0.5.5-Safety-Pass wurde keine reale Firewall-Regel angelegt oder entfernt.

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper inklusive read-only Blockstatus: **10/10 PASS**
- Control-UAC-Wrapper: **PASS**
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

## Noch offene oeffentliche Release-Gates

- isolierten Firewall-Block-/Undo-Test mit der kopierten `curl.exe` und beiden sichtbaren UAC-Bestaetigungen abschliessen
- Portable-Paket auf einem zweiten Windows-PC testen
- Rechte an Marken- und Bildassets abschliessend dokumentieren
- aktuelle Screenshots von `0.5.5-alpha` erstellen
- GitHub Private Vulnerability Reporting nach Erstellung des oeffentlichen Repositories aktivieren
- GitHub-Remote und Veroeffentlichung erst nach ausdruecklicher Freigabe einrichten

## Bewertung

TrackerRadar `0.5.5-alpha` beseitigt die unklare Situation nach einem fehlgeschlagenen Blockversuch: Der Nutzer sieht den bestaetigten Regelzustand und erhaelt eine Freigabeoption nur fuer sicher zuordenbare TrackerRadar-Aenderungen. Der reale isolierte Firewall-Wirkungstest bleibt bewusst als separates Release-Gate offen.
