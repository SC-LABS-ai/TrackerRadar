# TrackerRadar Alpha - Status

Stand: 2026-08-04, 16:58 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.0-alpha` ist als portable, lokale Windows-App mit Netzwerktransparenz, reversiblen Safe-Control-Funktionen und einem bewusst gestarteten Datei- und Ordnerzugriffs-Kurzscan lauffaehig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Hauptoberflaeche: ohne dauerhafte Administratorrechte
- Dateizugriffs-Scan: nur nach ausdruecklichem Start und sichtbarer Windows-UAC-Freigabe
- Cloud/Telemetrie: keine
- Zusaetzliche Runtime: keine Installation notwendig
- Hintergrunddienst oder eigener Treiber: keiner

## Neu in 0.5

- Sechste Ansicht `Dateizugriffe`
- Manueller Fuenf-Sekunden-Scan fuer:
  - Dokumente
  - Desktop
  - Downloads
  - OneDrive
  - Edge-Profile
  - Chrome-Profile
- Gruppierung nach Prozessname, PID, Programmpfad, Ordnerkategorie, beobachteter Aktion und Ereignisanzahl
- Beobachtete Aktionsarten:
  - `Geoeffnet`
  - `Ordner durchsucht`
- Keine Speicherung von Dateiinhalten
- Keine Speicherung einzelner Dateinamen im zusammengefassten Ergebnis
- Temporaere ETL- und CSV-Rohdaten werden direkt nach der lokalen Auswertung entfernt
- Eigene portable Scan-Engine und eigener lokal begrenzter UAC-Wrapper
- Der Dateizugriffs-Scan laeuft nicht automatisch im 30-Sekunden-Netzwerkintervall

## Seit 0.4 enthalten

- Internetzugriff einer ausgewaehlten Anwendung ueber eine ausgehende Windows-Firewall-Regel blockieren
- Ausgewaehlte neue, geaenderte oder auffaellige Autostarts deaktivieren
- Lokaler Change Vault mit Zeit, Aktion, Ziel und Status
- Ruecknahme unterstuetzter Firewall-, Registry- und Startup-Ordner-Aenderungen
- Keine automatische Blockierung oder Bereinigung
- Keine dauerhafte privilegierte App und kein neuer Windows-Dienst

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper: **9/9 PASS**
- Control-UAC-Wrapper: **3/3 PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **3/3 PASS**
- UI-Navigation: **6/6 PASS**
- Reeller Fuenf-Sekunden-Benutzerordner-Scan: **PASS**
- Prozess-zu-Ordnerkategorie-Zuordnung: **PASS**
- Automatische ETL-/CSV-Bereinigung: **PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer
- Change Vault nach Tests: leer

## Letzter Regressionstest

- Working Set nach 10 Sekunden: **182,1 MB**
- Privater Speicher nach 10 Sekunden: **163,3 MB**
- CPU-Zeit nach 10 Sekunden: **3,91 Sekunden**
- Ziel unter 200 MB Working Set: **PASS**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.5.0-alpha-portable.zip`
- Groesse: **223.816 Bytes**
- SHA-256: `23395ED9A141C773883B3EF4F31893AB96B91514F869FF29DB26BEBE8B024843`
- Build-Gates: App **10/10**, Control **9/9**, Control-Wrapper **3/3**, Access-Scan **6/6**, Access-Wrapper **3/3**, Navigation **6/6**

## Sicherheits- und Datenschutzgrenzen

- Der Dateizugriffs-Scan ist ein manueller Kurzscan, keine permanente Ueberwachung.
- Die Ereignisse zeigen beobachtetes Oeffnen oder Durchsuchen; sie beweisen nicht automatisch Lesen, Kopieren, Hochladen oder boeswillige Absicht.
- Programmpfade, Prozess-IDs und lokale Diagnoseprotokolle koennen maschinenspezifische Informationen enthalten und bleiben deshalb im ignorierten `data/`-Ordner.
- TrackerRadar entschluesselt keine HTTPS-Inhalte.
- Anbieter- und Zweckbezeichnungen fuer Netzwerkziele sind Heuristiken, kein Eigentums- oder Absichtsnachweis.
- TrackerRadar ist kein Ersatz fuer Antivirus, EDR oder professionelle Incident Response.

## Noch offene Release-Gates

- Isolierten Firewall-Block-/Undo-Test mit beiden sichtbaren UAC-Bestaetigungen vollstaendig abschliessen
- Clean-Checkout-Test auf einem zweiten Windows-PC
- Lizenzentscheidung treffen
- Rechte an allen Marken- und Bildassets abschliessend bestaetigen
- Aktuelle Screenshots aus dem 0.5-Release-Build erstellen
- Entscheidung zu Code Signing und Installer

## Bewertung

Version 0.5 beweist den zentralen Produktbaustein: TrackerRadar kann einen Windows-Prozess lokal einer sensiblen Ordnerkategorie zuordnen und die Ereignisse endnutzertauglich buendeln. Die Umsetzung bleibt bewusst schlank: kein Electron, keine Datenbank, keine Cloud, kein dauerhaftes ETW, kein Dienst und kein eigener Treiber.

Der naechste funktionale Schritt ist nicht mehr Datenerfassung, sondern eine vorsichtige Korrelation zwischen einem gebuendelten Dateizugriff und einer zeitnahen neuen externen Verbindung. Diese Korrelation darf nur als nachvollziehbare Evidenz dargestellt werden, nicht als automatische Malware-Behauptung.
