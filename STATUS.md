# TrackerRadar Alpha - Status

Stand: 2026-08-05, 12:45 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.3-alpha` ist als portable, lokale Windows-Anwendung fuer die interne Alpha-Nutzung fertiggestellt. Netzwerktransparenz, reversibler Safe Control, manueller Datei-/Ordnerzugriffs-Kurzscan, Deutsch/Englisch, versteckter Konsolenstart und lokale Berichte funktionieren im geprueften Windows-11-Stand.

- Standardstart: `Start-TrackerRadar.vbs`
- kompatibler Fallback: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Sprachen: Deutsch und English
- Hauptoberflaeche: ohne dauerhafte Administratorrechte
- PowerShell-Konsole beim Standardstart: verborgen
- Cloud und Produkttelemetrie: keine
- Hintergrunddienst oder eigener Treiber: keiner
- Lizenz: SC LABS Proprietary Freeware

## Neu in 0.5.3

- Windows-Script-Host-Launcher startet TrackerRadar ohne sichtbares PowerShell-Fenster.
- Das TrackerRadar-WPF-Fenster bleibt normal sichtbar.
- SC-LABS-Logo und TrackerRadar-Logo fuellen ihre abgerundeten Rahmen sauberer aus.
- Die Seitenleiste enthaelt kompakte Verweise auf:
  - `https://sclabs.uk/products/malwareradar/`
  - `https://sclabs.uk/products/privacyradar/`
- Die Webseiten werden ausschliesslich nach einem bewussten Klick im Standardbrowser geoeffnet.
- Kein eingebetteter Browser, kein Vorladen, kein Hintergrundaufruf und keine Downloadausfuehrung.
- Proprietaere Freeware-Lizenz festgelegt; Weiterverteilung, Rebranding und Verkauf bleiben ohne Zustimmung untersagt.
- Eine spaetere kommerzielle oder Pro-Version bleibt ausdruecklich vorbehalten.

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper: **9/9 PASS**
- Control-UAC-Wrapper: **3/3 PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **3/3 PASS**
- Lokalisierung, Unicode und Speicherung: **8/8 PASS**
- deutsche und englische Sprachschluessel: **146/146**
- versteckter Launcher und sichtbares App-Fenster: **7/7 PASS**
- sechs Ansichten, beide Sprachen, Logo-Fit und Produktlinks: **27/27 PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer

## Letzter vollstaendiger Regressionstest

- Working Set nach 10 Sekunden: **179,7 MB**
- privater Speicher nach 10 Sekunden: **160,5 MB**
- CPU-Zeit nach 10 Sekunden: **4,75 Sekunden**
- Ziel unter 180 MB Working Set: **PASS**
- Ziel unter 200 MB Working Set: **PASS**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.5.3-alpha-portable.zip`
- Groesse: **242.045 Bytes**
- SHA-256: `4F295B691624225100D06CC5EF7536147B262BF913273CF2CEE54A3358782C82`
- separate Hashdatei stimmt ueberein: **PASS**
- frische ZIP-Entpackung: **PASS**
- 17 Pflichtdateien vorhanden: **PASS**
- App-Selbsttest aus ZIP: **PASS**
- Lokalisierungstest aus ZIP: **PASS**
- versteckter Launcher aus ZIP: **PASS**
- 27 UI-Pruefungen aus ZIP: **PASS**
- `LICENSE.md`, VBS-Launcher und beide Sprachdateien enthalten: **PASS**

## Datenschutz und externe Links

- keine Cloud-Uebersetzung
- kein Benutzerkonto
- keine Produkttelemetrie
- keine Uebermittlung der Sprachwahl
- keine Dateiinhalte oder einzelnen Dateinamen im zusammengefassten Dateizugriffsergebnis
- MalwareRadar- und PrivacyRadar-Seiten werden nur nach einem bewussten Klick geoeffnet
- TrackerRadar laedt keine Inhalte dieser Seiten im Hintergrund

## Produktgrenzen

- Netzwerkansichten sind Momentaufnahmen aktiver TCP-Verbindungen und kein vollstaendiger Paketmitschnitt.
- Anbieter- und Zweckbezeichnungen bleiben erklaerende Heuristiken.
- `Unbekannter Dienst` beziehungsweise `Unknown service` ist keine Risikobewertung.
- Der Dateizugriffs-Scan ist ein manueller Fuenf-Sekunden-Kurzscan und keine Dauerueberwachung.
- Beobachtete Datei-Ereignisse beweisen nicht automatisch Lesen, Kopieren, Hochladen oder schaedliche Absicht.
- TrackerRadar ist kein Ersatz fuer Antivirus, EDR oder professionelle Incident Response.

## Noch offene oeffentliche Release-Gates

- isolierten Firewall-Block-/Undo-Test mit beiden sichtbaren UAC-Bestaetigungen abschliessen
- Clean-Checkout beziehungsweise Portable-Test auf einem zweiten Windows-PC durchfuehren
- Rechte an allen Marken- und Bildassets abschliessend bestaetigen
- aktuelle Screenshots der finalen Version 0.5.3 erstellen
- GitHub Private Vulnerability Reporting nach Erstellung des oeffentlichen Repositories aktivieren
- GitHub-Remote und oeffentliche Veroeffentlichung erst nach ausdruecklicher Freigabe einrichten

## Bewertung

TrackerRadar `0.5.3-alpha` ist ein stabiler, intern veroeffentlichungsfaehiger Portable-Alpha-Stand. Der Funktionsumfang bleibt bewusst schlank: lokale Transparenz, verstaendliche Evidenz, wenige bestaetigungspflichtige und reversible Aktionen. UI, Sprachwahl, Konsolenstart, Produktverweise und Lizenzierung sind abgeschlossen. Der reale isolierte Firewall-Endtest und ein zweites Windows-System bleiben vor einer oeffentlichen Downloadfreigabe offen.
