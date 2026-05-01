# TuS Gohfeld e.V. — Mitgliederverwaltung: Vollständiger System-Prompt

## Projektübersicht
Lokale, DSGVO-konforme Mitgliederverwaltung für den TuS Gohfeld von 1910 e.V. als native macOS-App und Web-App.
Entwickelt von **Stephan Schwenn** (GitHub: [Sparky32584](https://github.com/Sparky32584), Repository: `Sparky32584/TuS-Gohfeld-CRM`, privat).

---

## Architektur

### Tech-Stack
- **Backend:** Python 3.13 + Flask (`app.py`, ca. 2000 Zeilen), SQLite (WAL-Modus)
- **Frontend:** Vanilla JS + Chart.js, Single-Page-App (`templates/index.html`, ca. 1600 Zeilen)
- **Native App:** pywebview öffnet eigenes macOS-Fenster (kein Browser nötig), `run.py` als Launcher
- **PDF-Parsing:** pdfplumber (digitale PDFs), pytesseract + pdf2image + poppler (OCR für Scans)
- **PDF-Export:** reportlab für Jahresberichte
- **Design:** Vereinsfarben (#3156a3), Inter + JetBrains Mono Fonts, Dark Mode
- **Hosting:** Rein lokal auf `http://127.0.0.1:5000`, kein externer Server
- **Sync:** Daten via iCloud Drive zwischen Mac Mini und MacBook (nie gleichzeitig laufen — SQLite-Limitation)

### Datenhaltung
- **Code:** Lokal unter `~/tus-gohfeld-verwaltung/`, GitHub-Sync (privates Repo)
- **Daten:** iCloud Drive unter `~/Desktop/Vereine/TUS Gohfeld/Mitglieder/Daten/` (synchronisiert zwischen Mac Mini und MacBook)
- **Datenbank:** `mitglieder.db` (SQLite)
- **Dokumente:** `dokumente/` Ordner (hochgeladene Mitglieder-Dokumente)
- **Einstellungen:** `settings.json` (Farben, Dokumenttypen, Farbmarkierungen)

### Dateien & Pfade

```
~/tus-gohfeld-verwaltung/                    ← Lokal (Code, per GitHub sync)
├── app.py                                   ← Flask Backend (~2000 Zeilen)
├── templates/index.html                     ← Frontend SPA (~1600 Zeilen)
├── run.py                                   ← Native App Launcher (pywebview)
├── create-app.sh                            ← Erstellt ~/Applications/TuS Gohfeld.app
├── start.sh                                 ← Terminal-Start mit iCloud-Datenpfad
├── setup.sh                                 ← Installations-Script (venv, Pakete, Datenpfad-Wahl)
├── static/logo.png                          ← Vereinslogo (weiß auf schwarz)
├── requirements.txt                         ← Python-Abhängigkeiten
├── settings.json                            ← Persistente Einstellungen (Kopie)
├── pyvenv.cfg                               ← Python venv Konfiguration
├── README.md                                ← Dokumentation
├── GITHUB-ANLEITUNG.md                      ← Git/GitHub-Anleitung
├── venv/                                    ← Python 3.13 Virtual Environment
└── .git/                                    ← GitHub Repository

iCloud / Schreibtisch / Vereine / TUS Gohfeld / Mitglieder /
├── Daten/                                   ← Synchronisiert via iCloud
│   ├── mitglieder.db                        ← SQLite Datenbank
│   ├── dokumente/                           ← Hochgeladene Dokumente
│   └── settings.json                        ← App-Einstellungen
```

Die Umgebungsvariable `TUS_DATA_DIR` setzt den Datenpfad (Standard: `./data`).

---

## Datenbank-Schema (SQLite)

### Tabelle: `members`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
member_number TEXT UNIQUE          -- 10-stellig aus TuS-Import (z.B. 1000000001) oder 5-stellig auto-generiert (z.B. 00042)
first_name TEXT NOT NULL
last_name TEXT NOT NULL
birth_date TEXT                    -- Format: YYYY-MM-DD
gender TEXT DEFAULT ''             -- männlich/weiblich/divers oder leer
email TEXT DEFAULT ''
phone TEXT DEFAULT ''
street TEXT DEFAULT ''
city TEXT DEFAULT 'Löhne'
zip_code TEXT DEFAULT '32584'
entry_date TEXT                    -- Eintrittsdatum (YYYY-MM-DD)
exit_date TEXT                     -- Austrittsdatum (YYYY-MM-DD), leer = aktiv
color_mark TEXT DEFAULT ''         -- red/orange/yellow/green/blue/purple oder leer
app_status TEXT DEFAULT 'Nicht installiert'  -- Nicht installiert / Installiert / Aktiv
notes TEXT DEFAULT ''
is_active INTEGER DEFAULT 1       -- 1 = aktiv, 0 = inaktiv/ausgetreten
created_at TEXT                    -- datetime('now','localtime')
updated_at TEXT                    -- datetime('now','localtime')
```
Indizes: `idx_members_name` (last_name, first_name), `idx_members_active` (is_active)

### Tabelle: `groups_tbl` (3-stufige Hierarchie)
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
name TEXT NOT NULL
description TEXT DEFAULT ''
color TEXT DEFAULT '#4CAF50'       -- Hex-Farbcode, wird von Eltern geerbt
level INTEGER DEFAULT 1            -- 1=Abteilung, 2=Sportart, 3=Gruppe
parent_id INTEGER DEFAULT NULL     -- FK auf groups_tbl(id) ON DELETE CASCADE
sort_order INTEGER DEFAULT 0
```

### Tabelle: `member_groups` (N:M-Zuordnung)
```sql
member_id INTEGER NOT NULL         -- FK auf members(id) ON DELETE CASCADE
group_id INTEGER NOT NULL          -- FK auf groups_tbl(id) ON DELETE CASCADE
PRIMARY KEY (member_id, group_id)
```

### Tabelle: `documents`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
member_id INTEGER NOT NULL         -- FK auf members(id) ON DELETE CASCADE
doc_type TEXT NOT NULL DEFAULT 'Sonstiges'
original_name TEXT NOT NULL        -- Originaler Dateiname
stored_name TEXT NOT NULL          -- Format: {member_id}_{timestamp}_{secure_name}
uploaded_at TEXT                    -- datetime('now','localtime')
```
Index: `idx_documents_member` (member_id)

---

## Features (alle implementiert)

### Mitgliederverwaltung
- CRUD für Mitglieder (Stammdaten, Adresse, Kontakt, Notizen)
- **Farbmarkierungen** (6 Farben) mit konfigurierbaren Bedeutungen
- **App-Status Tracking** (Nicht installiert / Installiert / Aktiv)
- **Sortierung** per Klick auf Spaltenheader (Name, Nr, Alter, App, Eintritt) mit ▲/▼
- **Checkbox-Auswahl:** Einzeln oder "Alle auswählen" → "Ausgewählte löschen"
- **Einzellöschung** per Papierkorb-Icon + "Alle löschen" Button (doppelte Bestätigung)
- **Dokumentenverwaltung** pro Mitglied (Datenschutz, SEPA, Anträge etc.)
- **Schnelle Farbmarkierung** per Klick (Farbkreis-Icon rotiert durch Farben)

### Gruppen (3-stufige Hierarchie)
- **Abteilung → Sportart → Gruppe** (z.B. Turnen → Kinderturnen → Montag 16 Uhr)
- Verwaltung in Einstellungen UND auf Gruppen-Seite (Baumansicht)
- Keine vordefinierten Gruppen — Benutzer legt alles selbst an
- Dropdown mit Hierarchie im Mitglied-Formular und Filtern
- Kaskadierende Löschung (Abteilung löschen → Sportarten + Gruppen werden mitgelöscht)

### Daten-Import (Multi-Format)
- **PDF** (gescannt + digital): OCR mit deutschem Sprachmodell, Bildvorverarbeitung, TuS-Format-Parser
- **CSV**: Automatische Encoding- und Delimiter-Erkennung, Header-Mapping
- **TXT**: TuS Gohfeld Textformat (10-stellige MitglNr) oder einfaches Name-pro-Zeile
- **DOCX**: Word-Tabellen und -Paragraphen via python-docx
- **XML / SEPA-XML**: Vereins-XML-Exporte und SEPA-Lastschriftdateien
- **Abteilungs-Dropdown** über Upload-Zone: importierte Mitglieder werden automatisch zugeordnet
- **Automatische Geschlechterzuordnung** anhand des Vornamens (~120 männliche + ~120 weibliche Namen, deutsch + international, plus Endungs-Heuristik)
- Duplikat-Erkennung (INSERT OR IGNORE)
- OCR-Korrekturen: Umlaute (GéRling→Gößling, Bécks→Böcks, é→ö, ú→ü), Ortsnamen (Löhne, Bad Oeynhausen, Bünde, Lübbecke etc.)
- **Datumsnormalisierung:** DD.MM.YYYY, YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, YYYYMMDD, DD.MM.YY, MM/DD/YYYY → immer YYYY-MM-DD

### Dashboard
- **Stat-Cards:** Aktive Mitglieder, Gruppen, Karteileichen, Inaktive, App-Nutzer
- **Kreisdiagramme:** Alter (7 Buckets: 0-6, 7-14, 15-17, 18-30, 31-50, 51-65, 66+), Geschlecht, Mitgliedschaftsdauer (5 Buckets: <1, 1-5, 6-10, 11-20, 20+ Jahre), Gruppen, App-Nutzung
- CSV-Export

### Jahresauswertung
- Jahrwechsel-Dropdown (2020–2026)
- **KPIs:** Anfangsbestand, Zugänge, Abgänge, Endbestand, Nettoveränderung (absolut + prozentual)
- Linienchart monatliche Entwicklung
- **Jubiläen-Erkennung** (5/10/15/20/25/30/40/50 Jahre Mitgliedschaft)
- Zu- und Abgangslisten mit Gruppenzuordnung
- **PDF-Export** via reportlab (professionelles A4-Layout in Vereinsfarben mit KPI-Boxen, Tabellen)

### Einstellungen (komplett anpassbar, persistent in `settings.json`)
- **Farben** (6 Werte: primary, sidebar_bg, page_bg, card_bg, text, border — live-Vorschau)
- **Logo-Upload**
- **Spalten ein-/ausblenden** (Mitgliedsnr., Alter, Geschlecht, E-Mail, Telefon)
- **Karteileichen-Erkennung** ein/aus
- **Dokumenttypen** verwalten (hinzufügen/löschen)
- **Farbmarkierungen** mit benutzerdefinierten Bedeutungen
- **Gruppen-Verwaltung** (3-stufig, direkt in Einstellungen anlegen/bearbeiten/löschen)
- Zurücksetzen auf Standardwerte

### Filter & Suche
- **Freitext-Suche** (Name, E-Mail, Nr., Telefon, Ort)
- **Filter:** Gruppe/Abteilung (hierarchisch), Farbe, App-Status, nur Aktive
- Alle Filter kombinierbar

### Native macOS App
- pywebview öffnet eigenes Fenster (Python 3.13 + pyobjc)
- `create-app.sh` erstellt `~/Applications/TuS Gohfeld.app` mit Vereinslogo als Icon
- Startbar per Doppelklick, Spotlight oder Dock
- `run.py` setzt `/opt/homebrew/bin` im PATH (für poppler/tesseract)

---

## API-Endpunkte (REST, alle unter `/api/`)

### Mitglieder
- `GET /api/members?search=&group_id=&color_mark=&app_status=&active_only=true` — Liste mit Filtern
- `POST /api/members` — Neues Mitglied (JSON-Body, Mitgliedsnr. auto-generiert wenn leer)
- `GET /api/members/<id>` — Einzelnes Mitglied mit Gruppen + Dokumenten
- `PUT /api/members/<id>` — Mitglied aktualisieren (inkl. Gruppenzuordnung via `group_ids[]`)
- `DELETE /api/members/<id>` — Mitglied löschen (kaskadiert: Dokument-Dateien + DB-Einträge)
- `PATCH /api/members/<id>/color` — Farbmarkierung ändern

### Gruppen
- `GET /api/groups` — Flache Liste aller Gruppen mit `member_count`
- `GET /api/groups/tree` — Baumstruktur mit `children[]` und `total_members` (rekursiv)
- `POST /api/groups` — Neue Gruppe (mit `level`, `parent_id`, Farbe wird vom Eltern geerbt)
- `PUT /api/groups/<id>` — Gruppe bearbeiten
- `DELETE /api/groups/<id>` — Gruppe löschen (kaskadiert: Kinder + Enkel)

### Dokumente
- `POST /api/members/<id>/documents` — Upload (multipart/form-data, Feld "file" + "doc_type")
- `GET /api/documents/<id>/download` — Download
- `DELETE /api/documents/<id>` — Löschen (Datei + DB-Eintrag)

### Import (Multi-Format)
- `POST /api/import/pdf` — Datei hochladen und parsen (PDF, CSV, TXT, DOCX, XML), gibt `{members_found[], count}` zurück
- `POST /api/import/confirm` — Erkannte Mitglieder importieren (JSON: `{members[], group_id}`)

### Dashboard & Export
- `GET /api/stats` — Dashboard-Statistiken (Gesamt, Aktiv, Inaktiv, Geschlecht, Alter, Zugehörigkeit, Gruppen, Farben, App-Status, Karteileichen)
- `GET /api/stats/yearly?year=YYYY` — Jahresauswertung (Anfangsbestand, Zugänge, Abgänge, Endbestand, monatlich, Alter, Geschlecht, Gruppen, Jubiläen)
- `GET /api/export/yearly-pdf?year=YYYY` — Jahresbericht als PDF
- `GET /api/export/csv` — CSV-Export aller Mitglieder (Semikolon-getrennt, UTF-8)

### Einstellungen
- `GET /api/settings` — Einstellungen laden
- `PUT /api/settings` — Einstellungen speichern
- `POST /api/settings/reset` — Auf Standard zurücksetzen

---

## Einstellungen (`settings.json`)

```json
{
  "colors": {
    "primary": "#3156a3",
    "sidebar_bg": "#1e2a4a",
    "page_bg": "#f5f6fa",
    "card_bg": "#ffffff",
    "text": "#1a1f36",
    "border": "#e2e5ef"
  },
  "display": {
    "show_member_number": true,
    "show_age": true,
    "show_gender": true,
    "show_email": false,
    "show_phone": false,
    "stale_detection": true
  },
  "doc_types": [
    "Datenschutzerklärung", "SEPA-Lastschriftmandat",
    "Mitgliedsantrag", "Einverständniserklärung",
    "Ärztliches Attest", "Sonstiges"
  ],
  "color_meanings": {
    "red": "Beitrag ausstehend",
    "orange": "Daten unvollständig",
    "yellow": "Kontaktversuch offen",
    "green": "Alles vollständig",
    "blue": "Vorstand / Funktionsträger",
    "purple": "Ehrenmitglied"
  }
}
```

---

## Farbmarkierungen (6 Farben)

Mitglieder können farblich markiert werden. Die Bedeutung ist konfigurierbar:
- 🔴 **red** — Beitrag ausstehend
- 🟠 **orange** — Daten unvollständig
- 🟡 **yellow** — Kontaktversuch offen
- 🟢 **green** — Alles vollständig
- 🔵 **blue** — Vorstand / Funktionsträger
- 🟣 **purple** — Ehrenmitglied

---

## Frontend (index.html — SPA)

Das Frontend ist eine einzige HTML-Datei mit eingebettetem CSS und JavaScript. Es kommuniziert ausschließlich über die REST-API mit dem Backend.

### Ansichten/Seiten (SPA-Navigation):
1. **Dashboard** — KPI-Kacheln (Gesamt, Aktiv, Inaktiv, Karteileichen), Kreisdiagramme (Alter, Geschlecht, Zugehörigkeit, Gruppen) via Chart.js
2. **Mitgliederliste** — Tabelle mit Suche, Filter nach Gruppe/Farbe/App-Status, Sortierung per Spaltenheader, Farbmarkierungsdots, Checkbox-Auswahl
3. **Mitglied-Detail** — Formular zum Anlegen/Bearbeiten mit allen Feldern, Gruppenauswahl (Checkboxen aus `/api/groups/tree`), Dokumenten-Upload und -Verwaltung
4. **Gruppen-Verwaltung** — Hierarchischer Baum (Abteilung → Sportart → Gruppe)
5. **Import** — Datei-Upload (PDF/CSV/TXT/DOCX/XML), Vorschau-Tabelle mit Bearbeitungsmöglichkeit vor dem Bestätigen, Gruppenzuordnung per Dropdown
6. **Jahresauswertung** — Jahresberichte mit Tabellen und Diagrammen, PDF-Export
7. **Einstellungen** — Farben, Anzeigeoptionen, Dokumenttypen, Farbmarkierungs-Bedeutungen, Gruppen-Manager

### Design:
- Dunkle Sidebar (Navigation) links
- Heller Content-Bereich rechts
- Responsive (funktioniert auf Desktop und iPad)
- Farbschema konfigurierbar (Standard: Blau #3156a3)
- Schriften: Inter (Text), JetBrains Mono (Zahlen/Code)
- Alle API-Calls gehen über die `api()` Hilfsfunktion (JSON fetch wrapper)

---

## Besondere Logik

### Karteileichen-Erkennung
Ein Mitglied gilt als "Karteileiche" wenn:
- Aktiv UND Eintritt > 5 Jahre her UND keiner Gruppe zugeordnet
- ODER: Aktiv UND kein Eintrittsdatum UND keine E-Mail UND kein Telefon

### Mitgliedsnummer-Generierung
- **Auto-generiert:** Höchste vorhandene Nummer + 1, auf 5 Stellen mit Nullen aufgefüllt (z.B. "00042")
- **Aus TuS-Import:** 10-stellig (z.B. "1000000001") — wird 1:1 übernommen

### Geschlechts-Erkennung beim Import
- ~120 bekannte männliche Vornamen (deutsch + international)
- ~120 bekannte weibliche Vornamen (deutsch + international)
- Endungs-Heuristik als Fallback (weiblich: -a, -e, -ine, -ette, -ina; männlich: -er, -us, -ard, -helm, -bert, -fried)
- Bei Unsicherheit bleibt das Feld leer (kein falsches Raten)

### Jubiläen
Automatische Erkennung von Mitgliedschafts-Jubiläen: 5, 10, 15, 20, 25, 30, 40, 50 Jahre

---

## OCR-Pipeline (für gescannte TuS Gohfeld PDFs)

1. PDF → Bilder konvertieren (pdf2image, 400 DPI)
2. Bildvorverarbeitung: Graustufen → Kontrast ×2 → Schärfe ×2 → Helligkeit +20% → Schwellwert-Binarisierung (< 140 → schwarz)
3. OCR mit `deu+eng` Sprachmodell (pytesseract, `--psm 6`, `preserve_interword_spaces=1`)
4. Text-Parsing: 10-stellige Mitgliedsnummer → Nachname + Straße + Geburtsdatum (Zeile 1), Vorname + PLZ/Ort + Telefon (Zeile 2), E-Mail + weitere Telefonnummern (Zeile 3+)
5. OCR-Korrekturen: Umlaute (é→ö, ú→ü), Namen (GéRling→Gößling, Bécks→Böcks), Orte (Löhne, Bad Oeynhausen, Bünde, Lübbecke, Hiddenhausen, Kirchlengern)
6. Automatische Geschlechterzuordnung (`guess_gender`) anhand Vorname
7. Duplikat-Entfernung (gleiche Mitgliedsnummer)
8. Abteilungs-Erkennung aus PDF-Header (z.B. "Abt. (3) Turnen")

---

## DSGVO-Konformität

- Alle Daten ausschließlich lokal gespeichert
- Keine Cloud-Dienste, keine externen Server, kein Tracking
- Bei iCloud-Sync: Daten in persönlichem iCloud-Konto (Apple-Verschlüsselung)
- GitHub-Repository enthält keine Mitgliederdaten (.gitignore)
- Löschung kaskadiert (Mitglied → Dokumente → Dateien)
- CSV-Export für Auskunftsanfragen nach Art. 15 DSGVO

---

## Technische Setup-Details

### Mac Mini (Hauptrechner)
- Homebrew, Git, Python 3.13, gh CLI
- Tesseract 5+ mit `deu` Sprachpaket, poppler für pdf2image
- venv unter `~/tus-gohfeld-verwaltung/venv/` (Python 3.13)
- GitHub User: Sparky32584, E-Mail: stephans1987@icloud.com
- `host="127.0.0.1"` statt `localhost` (macOS IPv6-Problem)

### MacBook (Zweitrechner)
- Identisches Setup über `gh repo clone` + `pip install`
- Gleiche iCloud-Datenbank über synchronisierten Schreibtisch
- App nur auf einem Mac gleichzeitig laufen lassen (SQLite-Limitation)

### Abhängigkeiten

**pip (requirements.txt):**
```
flask==3.0.0, pdfplumber==0.11.0, werkzeug==3.0.1, reportlab==4.1.0, matplotlib==3.8.2
```
**Optional pip:** pytesseract, pdf2image, Pillow, pywebview, python-docx

**brew:** python@3.13, gh, tesseract, tesseract-lang, poppler

**Upload-Limit:** 100 MB (`MAX_CONTENT_LENGTH = 100 * 1024 * 1024`)
**Erlaubte Datei-Typen:** pdf, png, jpg, jpeg, doc, docx, odt, txt

---

## Start-Befehle

### Native App (bevorzugt)
```bash
# Per Doppelklick: ~/Applications/TuS Gohfeld.app
# Oder per Terminal:
cd ~/tus-gohfeld-verwaltung && source venv/bin/activate && python3 run.py
```

### Browser-Modus
```bash
cd ~/tus-gohfeld-verwaltung && ./start.sh
# Dann: http://127.0.0.1:5000
```

### Netzwerk-Freigabe
```bash
# ngrok installieren: brew install ngrok
# Terminal 1: ./start.sh
# Terminal 2: ngrok http 5000
# Link teilen: https://abc123.ngrok-free.app
```

---

## Bekannte Probleme & Lösungen

| Problem | Lösung |
|---------|--------|
| Port 5000 belegt | `lsof -ti:5000 \| xargs kill -9 2>/dev/null` |
| Weiße Seite im Browser | Safari Cache leeren (Cmd+Shift+R oder Entwickler → Cache leeren) |
| poppler nicht gefunden (pywebview) | `run.py` fügt `/opt/homebrew/bin` zum PATH hinzu |
| OCR-Fehler bei Umlauten | `deu+eng` Sprachmodell + Bildvorverarbeitung (Kontrast, Schärfe, Binarisierung) |
| Duplikate beim Import | INSERT OR IGNORE INTO members |
| Git Push rejected | `git pull --rebase origin main` dann `git push` |
| Dateien von Claude | landen in ~/Downloads/ oft mit Suffix — `ls -t ~/Downloads/app*.py \| head -1` prüfen |

---

## Hinweise für Weiterentwicklung

- Frontend ist eine Single-Page-App in einer einzigen HTML-Datei (`templates/index.html`)
- Alle API-Calls gehen über die `api()` Hilfsfunktion (JSON fetch wrapper)
- Chart.js für alle Diagramme (Dashboard + Jahresauswertung)
- Gruppen-Checkboxen im Mitglied-Formular werden aus `/api/groups/tree` geladen
- Einstellungen-Seite hat eigenen Gruppen-Manager mit Baumansicht
- iCloud synchronisiert den Schreibtisch — Datenbank ist auf beiden Macs verfügbar
- SQLite erlaubt nur einen gleichzeitigen Schreibzugriff — App nicht auf beiden Macs parallel laufen lassen
- Migration-Logik in `init_db()`: Spalten werden per `ALTER TABLE ... ADD COLUMN` hinzugefügt wenn nicht vorhanden (fehlertolerantes Schema-Update)
