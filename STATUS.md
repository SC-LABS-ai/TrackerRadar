# TrackerRadar Alpha - Status

Stand: 2026-08-05, 14:21 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.4-alpha` ist als portable, lokale Windows-Anwendung fertiggestellt. Dieser Pass war ausschliesslich ein finaler UI-Polish fuer Logo, Sidebar-Link und Footer. Monitoring, Dateizugriff, Firewall, Autostart, Change Vault, Sprache und Launcherlogik wurden nicht umgebaut.

- Standardstart: `Start-TrackerRadar.vbs`
- kompatibler Fallback: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Sprachen: Deutsch und English
- PowerShell-Konsole beim Standardstart: verborgen
- Cloud und Produkttelemetrie: keine
- Hintergrunddienst oder eigener Treiber: keiner
- Lizenz: SC LABS Proprietary Freeware

## Neu in 0.5.4

- Die engen MalwareRadar- und PrivacyRadar-Buttons wurden aus dem gruenen Sidebar-Bereich entfernt.
- `MORE SC LABS APPS` bleibt erhalten; darunter steht jetzt der voll lesbare Link `sclabs.uk`.
- MalwareRadar und PrivacyRadar stehen als gut lesbare Akzentlinks hinter der Versionsanzeige im Footer.
- Der gesamte Footer-Block ist zusaetzlich vom rechten Rand eingerueckt.
- Der gemessene Logo-Hintergrund `#00020A` wird im Rahmen verwendet, damit Bild und Container optisch verschmelzen.
- SC-LABS-Logo und TrackerRadar-Logo wurden innerhalb ihrer bestehenden abgerundeten Rahmen vergroessert.
- Alle drei externen Ziele sind fest allowlisted und werden nur nach bewusstem Klick geoeffnet.

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper: **9/9 PASS**
- Control-UAC-Wrapper: **3/3 PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **3/3 PASS**
- Lokalisierung, Unicode und Speicherung: **8/8 PASS**
- versteckter Launcher und sichtbares App-Fenster: **7/7 PASS**
- sechs Ansichten, beide Sprachen, Logo-Fit, Sidebar-Link und Footer-Links: **31/31 PASS**
- deutsche und englische Sprachschluessel: **146/146**
- GUI-Fehlerausgabe: leer

## Letzter vollstaendiger Regressionstest

- Working Set nach 10 Sekunden: **179,4 MB**
- privater Speicher nach 10 Sekunden: **159,0 MB**
- CPU-Zeit nach 10 Sekunden: **3,91 Sekunden**
- Ziel unter 180 MB Working Set: **PASS**
- Ziel unter 200 MB Working Set: **PASS**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.5.4-alpha-portable.zip`
- Groesse: **242.468 Bytes**
- SHA-256: `3DE967B311D5B4EDF06F009B201BFEFF0E323FF7F2B1154CC9D55EE9E63235F0`
- separate Hashdatei stimmt ueberein: **PASS**
- frische ZIP-Entpackung: **PASS**
- 17 Pflichtdateien vorhanden: **PASS**
- App-, Lokalisierungs-, Launcher- und UI-Test aus ZIP: **PASS**

## Datenschutz und externe Links

- `sclabs.uk` wird nur nach Klick aus der Sidebar geoeffnet.
- MalwareRadar und PrivacyRadar werden nur nach Klick aus dem Footer geoeffnet.
- kein eingebetteter Browser, kein Vorladen und kein Hintergrundzugriff
- keine Dateiinhalte oder einzelnen Dateinamen im zusammengefassten Dateizugriffsergebnis

## Noch offene oeffentliche Release-Gates

- isolierten Firewall-Block-/Undo-Test mit beiden sichtbaren UAC-Bestaetigungen abschliessen
- Portable-Paket auf einem zweiten Windows-PC testen
- Rechte an allen Marken- und Bildassets abschliessend bestaetigen
- aktuelle Screenshots der Version 0.5.4 erstellen
- GitHub Private Vulnerability Reporting nach Erstellung des oeffentlichen Repositories aktivieren
- GitHub-Remote und oeffentliche Veroeffentlichung erst nach ausdruecklicher Freigabe einrichten

## Bewertung

TrackerRadar `0.5.4-alpha` ist der abgeschlossene lokale UI- und Portable-Stand. Die von der Nutzerpruefung gemeldeten Punkte sind umgesetzt, ohne die bestaetigte Produktfunktion zu veraendern.
