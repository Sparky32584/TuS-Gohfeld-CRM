# TuS Gohfeld — Mitgliederverwaltung

Lokale, DSGVO-konforme Mitgliederverwaltung für den TuS Gohfeld e. V.

**Keine Cloud. Kein Tracking. Keine Telemetrie.**
Alle Daten bleiben auf dem Mac bzw. in der persönlichen iCloud Drive.

---

## Features

- **Mitgliederverwaltung** mit Farbmarkierungen, Gruppen-Zuordnung, Karteileichen-Erkennung
- **3-stufige Gruppenhierarchie** (Abteilung → Sportart → Gruppe) mit Farbvererbung
- **Import** aus PDF (digital & OCR), CSV, TXT, DOCX, SEPA-XML (pain.008)
- **Dashboard** mit 6 Charts: Geschlecht, Alter, Mitgliedsdauer, Farben, App-Status, Gruppen
- **Jahresauswertung** mit Zugängen, Abgängen, Jubiläen (5/10/15/20/25/30/40/50 Jahre)
- **Dokumentenverwaltung** pro Mitglied (PDF/Bild/Word)
- **Export** nach CSV (Excel-kompatibel) und Jahres-PDF
- **Anpassbares Design**: Farbschema, Anzeige-Optionen, Dokumenttypen
- **Native macOS-App** via pywebview — keine sichtbaren Browser-Elemente

---

## Tech-Stack

| Komponente     | Version   | Zweck                              |
|----------------|-----------|------------------------------------|
| Python         | 3.9+      | Backend                            |
| Flask          | 3.0       | Webserver                          |
| SQLite         | eingebaut | Datenbank (WAL-Mode)               |
| pdfplumber     | 0.11      | Digitale PDFs parsen               |
| pytesseract    | 0.3       | OCR (mit Tesseract)                |
| pdf2image      | 1.17      | PDF→Bild für OCR                   |
| Pillow         | 10.2      | Bildverarbeitung                   |
| reportlab      | 4.1       | PDF-Export                         |
| python-docx    | 1.1       | Word-Dokumente                     |
| pywebview      | 5.0       | Native macOS-Fenster               |
| Chart.js       | 4.4       | Dashboard-Charts (Frontend-CDN)    |

---

## Installation

### Voraussetzungen

- macOS 11+ (Big Sur oder neuer)
- Python 3.9 oder neuer
- [Homebrew](https://brew.sh) (wird vom Setup-Skript automatisch vorgeschlagen)

### Schritt 1 — Projekt klonen/kopieren

Kopieren Sie den `Programm/`-Ordner nach `~/Desktop/Vereine/TUS Gohfeld/Mitglieder/Programm/`
(oder einen anderen Ort Ihrer Wahl).

### Schritt 2 — Setup ausführen

```bash
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/Programm/
./setup.sh
```

Das Skript erledigt:
1. Python-Version prüfen
2. Homebrew-Tools (Tesseract, Poppler) installieren
3. `venv/` anlegen und alle Python-Pakete installieren
4. Daten-Ordner wählen (Lokal / iCloud / Custom)
5. `.env.local` mit dem Pfad speichern

### Schritt 3 — Starten

Drei Start-Varianten:

```bash
./start.sh         # Terminal + Browser automatisch öffnen
python3 run.py     # Direkt als Fenster (ohne Browser)
./create-app.sh    # Einmalig: .app-Bundle in ~/Applications erzeugen
```

Nach `create-app.sh` erscheint **„TuS Gohfeld.app"** in `~/Applications/`.
Doppelklick = Start. Ins Dock ziehen für Schnellzugriff.

---

## Projekt-Struktur

```
Programm/
├── app.py                 # Flask-Backend (~2100 Zeilen)
├── templates/
│   └── index.html         # Single-Page-App Frontend (~1600 Zeilen)
├── static/
│   └── logo.png           # Vereinswappen (optional)
├── run.py                 # pywebview-Launcher
├── setup.sh               # Installation
├── start.sh               # Terminal-Start mit Browser
├── create-app.sh          # macOS .app-Bundle erzeugen
├── requirements.txt       # Python-Abhängigkeiten
├── .env.local             # automatisch: TUS_DATA_DIR
├── .gitignore             # Schützt Daten, venv, etc.
├── venv/                  # Virtuelles Environment (nach setup.sh)
└── README.md              # Diese Datei
```

---

## Daten-Ordner

**Alle Mitgliederdaten werden hierhin geschrieben, NICHT ins Projekt!**

Standard-Pfad (iCloud):
```
~/Library/Mobile Documents/com~apple~CloudDocs/TuS-Gohfeld-Daten/
├── mitglieder.db          # SQLite-Datenbank
├── dokumente/             # Hochgeladene Dateien pro Mitglied
├── uploads/               # Temporärer Import-Puffer
└── settings.json          # Benutzereinstellungen (Farben, Gruppen, …)
```

Mit iCloud Drive synchronisiert sich die Datenbank automatisch zwischen
Mac Mini und MacBook. **Vor dem Wechsel des Geräts: App auf dem einen
Gerät schließen, vor dem Öffnen auf dem anderen 30 Sek. Sync-Zeit lassen.**

### Daten-Ordner ändern

```bash
# Option A: permanent
nano .env.local       # Pfad ändern
./start.sh            # neu starten

# Option B: einmalig
TUS_DATA_DIR="/anderer/pfad" ./venv/bin/python3 app.py
```

---

## Import-Formate

| Format       | Erkennung                  | Notizen                              |
|--------------|----------------------------|--------------------------------------|
| **PDF-digital** | Layout mit Spalten      | `pdfplumber`, schnellster Import     |
| **PDF-gescannt** | Bilder, OCR             | `tesseract deu+eng`, Korrekturliste  |
| **CSV**      | `;` oder `,` Trennzeichen  | UTF-8 und Latin-1 werden erkannt     |
| **TXT**      | TuS-10-stellige Nummer     | 3-zeilige Blöcke: Nr + Adresse + Geb |
| **DOCX**     | Tabellen, Fließtext        | `python-docx`                        |
| **XML**      | SEPA `pain.008` Namespace  | `DbtrNm`, `IBAN`, `MndtId` werden geparst |

### OCR-Korrekturen

Das Programm kennt gängige OCR-Fehler bei Löhner Straßen- und Ortsnamen:

```
"L6hne"    → "Löhne"
"Gohféld"  → "Gohfeld"
"Mennighuffen" → "Mennighüffen"
...
```

Weitere Korrekturen lassen sich in `app.py` unter `OCR_CITY_MAP` / `OCR_NAME_MAP` ergänzen.

---

## Bekannte Probleme

### „OCR findet nichts / Unscharfer Text"
- Prüfen: `brew list tesseract` → installiert?
- Prüfen: `brew list poppler` → installiert?
- Prüfen: `PATH` enthält `/opt/homebrew/bin`? (wird von `run.py` gesetzt,
  bei Terminal-Start muss `start.sh` verwendet werden)

### „Port 5000 bereits in Verwendung"
`run.py` sucht automatisch den nächsten freien Port (5000–5050). Bei
`start.sh` kann der Port in `app.py` (letzte Zeile) angepasst werden.

### „Datenbank gesperrt"
SQLite im WAL-Mode verträgt gleichzeitige Lese-/Schreib­operationen.
Falls doch `database is locked` auftritt: alle TuS-Fenster schließen,
dann einzeln neu öffnen.

### iCloud-Konflikte
Wenn auf beiden Macs gleichzeitig geschrieben wird, erzeugt iCloud
`mitglieder 2.db`. **Prophylaxe**: Immer nur auf einem Gerät gleichzeitig
arbeiten.

---

## Entwicklung

### Logs

Flask schreibt nach stdout. Bei `start.sh` im Terminal sichtbar,
bei der App via:

```bash
tail -f ~/Library/Logs/TuS-Gohfeld.log    # falls eingerichtet
```

### Tests

Grundlegender Smoke-Test:

```bash
./venv/bin/python3 -c "from app import app; print(len(list(app.url_map.iter_rules())), 'Routen')"
```

---

## DSGVO-Hinweise

- Alle Daten werden **lokal** gespeichert, nie in externe Clouds übertragen
  (ausgenommen Apple iCloud Drive bei entsprechender Konfiguration durch den
  Nutzer — dies ist eine bewusste Entscheidung)
- **Keine** Analyse- oder Tracking-Tools
- **Keine** Schriften werden von Google geladen, **außer** die lokalen CSS-Fonts
  vom Google-Fonts-CDN (Inter/JetBrains Mono). Wer dies vermeiden möchte,
  kann die Fonts lokal einbinden — siehe Kommentar in `templates/index.html`.
- Chart.js wird vom jsDelivr-CDN geladen. Für Offline-Betrieb die Datei
  `chart.umd.min.js` herunterladen und in `static/` ablegen.
- Dokumente werden unter `dokumente/<mitglied_id>/` abgelegt und mit dem
  Mitglied gelöscht (Cascade).
- Die Löschfunktion entfernt **nur** die Datenbank-Einträge — manuell
  abgelegte PDFs im `dokumente/`-Ordner bleiben erhalten, wenn sie
  außerhalb der App hinzugefügt wurden.

---

## Lizenz / Copyright

Erstellt für den TuS Gohfeld e. V.
Interne Nutzung — keine Weitergabe an Dritte ohne Rücksprache.

---

## Support

Bei Problemen:
1. Zuerst dieses README prüfen
2. `setup.sh` erneut ausführen
3. `venv/` löschen und `setup.sh` neu
4. Log-Ausgabe im Terminal beim Start sichten
