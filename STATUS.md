# TrackerRadar Alpha - Status

Stand: 2026-08-04, 19:49 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.2-alpha` ist als portable, lokale Windows-App mit Netzwerktransparenz, reversiblen Safe-Control-Funktionen, manuellem Datei-/Ordnerzugriffs-Kurzscan und vollstaendig lokaler Deutsch-/Englisch-Auswahl lauffaehig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Sprachen: Deutsch und English
- Sprachwahl: sofort umschaltbar und lokal gespeichert
- Hauptoberflaeche: ohne dauerhafte Administratorrechte
- Cloud/Telemetrie: keine
- Hintergrunddienst oder eigener Treiber: keiner

## Neu in 0.5.2

- Windows-Standard-Dropdown durch ein eigenes dunkles TrackerRadar-Template ersetzt
- Sprachfeld jetzt passend zum Gesamtbild:
  - dunkler Hintergrund
  - teal-farbene Umrandung
  - abgerundete Ecken
  - passende Hover-, Auswahl- und Offen-Zustaende
  - dunkle Dropdown-Eintraege ohne weisse Windows-Systemflaeche
- Sprachfeld und Haupt-Scan-Button auf einheitliche **52 Pixel** Hoehe ausgerichtet
- WPF Layout-Rounding und Device-Pixel-Snapping aktiviert
- keine Aenderung an Monitoring, Datei-Scan, Firewall, Autostart oder Rollback

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper: **9/9 PASS**
- Control-UAC-Wrapper: **3/3 PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **3/3 PASS**
- Lokalisierungsdateien, Unicode und Speicherung: **8/8 PASS**
- Ansichten, Sprachen und UI-Style-Gates: **17/17 PASS**
- eigenes Sprach-Template geladen: **PASS**
- Sprachfeld-Hoehe 52 Pixel: **PASS**
- Scan-Button-Hoehe 52 Pixel: **PASS**
- sechs Ansichten in beiden Sprachen: **PASS**
- `Unbekannter Dienst` / `Unknown service`: **PASS**
- Sprachwahl nach Neustart wiederhergestellt: **PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer

## Letzter Regressionstest

- Working Set nach 10 Sekunden: **175,6 MB**
- privater Speicher nach 10 Sekunden: **155,1 MB**
- CPU-Zeit nach 10 Sekunden: **3,94 Sekunden**
- Ziel unter 180 MB Working Set: **PASS**
- Ziel unter 200 MB Working Set: **PASS**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.5.2-alpha-portable.zip`
- Groesse: **236.231 Bytes**
- SHA-256: `55947FA6630B6FB888400DEEDB7D3D18D580537BE5EF330C5E47B4C657241239`
- Hashdatei stimmt ueberein: **PASS**
- Sprachmodul und beide Locale-Dateien im ZIP: **PASS**
- App-, Lokalisierungs- und UI-Test aus frischer Entpackung: **PASS**

## Datenschutz

- keine Cloud-Uebersetzung
- kein Benutzerkonto
- keine Uebermittlung der Sprachwahl
- gespeichert wird nur `de` oder `en` in der lokalen, von Git ausgeschlossenen Einstellungsdatei
- Scan-, Prozess- und Dateizugriffsdaten bleiben unveraendert lokal

## Grenzen

- Anbieter- und Zweckbezeichnungen bleiben erklaerende Heuristiken; die Sprachumschaltung verbessert keine technische Anbietererkennung.
- `Unknown service` bedeutet weiterhin, dass aus dem lokalen DNS-Cache kein verlaesslicher Anbieter abgeleitet werden konnte.
- Der Dateizugriffs-Scan bleibt ein manueller Kurzscan und keine Dauerueberwachung.
- TrackerRadar ist kein Ersatz fuer Antivirus, EDR oder professionelle Incident Response.

## Noch offene oeffentliche Release-Gates

- isolierten Firewall-Block-/Undo-Test mit beiden sichtbaren UAC-Bestaetigungen abschliessen
- Clean-Checkout-Test auf einem zweiten Windows-PC
- Lizenzentscheidung treffen
- Rechte an Marken- und Bildassets abschliessend bestaetigen
- aktuelle Release-Screenshots erstellen
- Entscheidung zu Code Signing und Installer

## Bewertung

Version 0.5.2 behebt den sichtbaren Stilbruch des hellen Windows-Sprachfelds, ohne wichtige Produktfunktionen anzufassen. Die Oberflaeche wirkt nun konsistent dunkel, abgerundet und farblich an die vorhandenen TrackerRadar-Buttons angepasst. Netzwerk-, Access-Scan- und Safe-Control-Verhalten wurden nicht veraendert.
