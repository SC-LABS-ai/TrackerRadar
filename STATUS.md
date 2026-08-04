# TrackerRadar Alpha - Status

Stand: 2026-08-04, 17:48 Uhr Europe/Berlin

## Ergebnis

TrackerRadar `0.5.1-alpha` ist als portable, lokale Windows-App mit Netzwerktransparenz, reversiblen Safe-Control-Funktionen, manuellem Datei-/Ordnerzugriffs-Kurzscan und vollstaendig lokaler Deutsch-/Englisch-Auswahl lauffaehig.

- Startdatei: `Start-TrackerRadar.cmd`
- Installation: nicht erforderlich
- Sprachen: Deutsch und English
- Sprachwahl: sofort umschaltbar und lokal gespeichert
- Hauptoberflaeche: ohne dauerhafte Administratorrechte
- Cloud/Telemetrie: keine
- Hintergrunddienst oder eigener Treiber: keiner

## Neu in 0.5.1

- Sprachwahlschalter oben rechts in der Anwendung
- vollstaendige lokale Uebersetzung von:
  - Navigation und Seitentiteln
  - Buttons und Statusmeldungen
  - Tabellenueberschriften
  - Anbieter-, Zweck-, Status- und Zugriffsbezeichnungen
  - unterstuetzten Bestaetigungs- und Detaildialogen
  - Dateizugriffs- und Change-Vault-Ansichten
- getrennte UTF-8-Sprachdateien:
  - `locales/de.json`
  - `locales/en.json`
- lokales Lokalisierungsmodul `TrackerRadar.Localization.ps1`
- Spracheinstellung ausschliesslich unter `data/ui-settings.json`
- keine Cloud-Uebersetzung und keine neue Runtime
- Sprachwechsel verwendet den letzten lokalen Scan erneut und loest keinen neuen Systemscan aus

## Verifizierte Funktionen

- App-Kern: **10/10 PASS**
- Control-Helper: **9/9 PASS**
- Control-UAC-Wrapper: **3/3 PASS**
- Dateizugriffs-Parser und Datenschutzregeln: **6/6 PASS**
- Dateizugriffs-UAC-Wrapper: **3/3 PASS**
- Lokalisierungsdateien, Unicode und Speicherung: **8/8 PASS**
- zweisprachige UI und Navigation: **14/14 PASS**
- sechs Ansichten in beiden Sprachen: **PASS**
- German Unicode labels verified by code point: **PASS**
- `Unbekannter Dienst` / `Unknown service`: **PASS**
- Sprachwahl nach Neustart wiederhergestellt: **PASS**
- GUI-Start: **PASS**
- GUI-Fehlerausgabe: leer

## Letzter Regressionstest

- Working Set nach 10 Sekunden: **198,8 MB**
- privater Speicher nach 10 Sekunden: **180,7 MB**
- CPU-Zeit nach 10 Sekunden: **3,52 Sekunden**
- Ziel unter 200 MB Working Set: **PASS**
- GUI-Fehler: **keine**

## Portable-Paket

- Datei: `dist/TrackerRadar-0.5.1-alpha-portable.zip`
- Groesse: **234.976 Bytes**
- SHA-256: `8ECD4C966F93A70B67EFD778713F61BDA06BBA679EF06EB59A28D529D01ED1DA`
- Hashdatei stimmt ueberein: **PASS**
- Sprachmodul und beide Locale-Dateien im ZIP: **PASS**
- App-, Lokalisierungs- und zweisprachiger UI-Test aus frischer Entpackung: **PASS**

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

Version 0.5.1 macht TrackerRadar fuer deutsch- und englischsprachige Endnutzer verwendbar, ohne die Architektur aufzublaehen. Die Uebersetzung ist vollstaendig lokal, separat testbar und Bestandteil des Portable-Builds. Netzwerk-, Access-Scan- und Safe-Control-Verhalten wurden nicht veraendert.
