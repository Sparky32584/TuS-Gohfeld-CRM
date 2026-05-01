# GitHub-Synchronisation zwischen Mac Mini und MacBook

Schritt-für-Schritt-Anleitung, um das **Programm** (nicht die Daten!) per
Git/GitHub zwischen zwei Macs zu synchronisieren.

> **WICHTIG:** Dank der `.gitignore` werden die Mitgliederdaten **niemals**
> ins Git-Repo übernommen — nur der Code.

---

## Einmalige Einrichtung (Mac Mini = „Haupt-Rechner")

### 1. Git-Identität setzen (falls noch nicht geschehen)

```bash
git config --global user.name  "Stephan Schwenn"
git config --global user.email "stephan@example.com"    # anpassen
```

### 2. Lokales Repo initialisieren

```bash
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/Programm/
git init
git add .
git status                    # prüfen: keine *.db, kein venv/, kein data/!
git commit -m "Initiales Setup TuS Gohfeld Mitgliederverwaltung"
```

### 3. Privates GitHub-Repo anlegen

1. Browser: https://github.com/new
2. Repository name: `tus-gohfeld-mitgliederverwaltung`
3. **Privacy: Private** (❗ wichtig — niemals Public, auch wenn keine Daten drin sind)
4. **Nicht** „Add README / .gitignore / license" anhaken — haben wir schon
5. „Create repository"

GitHub zeigt dann die Remote-URL:
```
https://github.com/Sparky32584/tus-gohfeld-mitgliederverwaltung.git
```

### 4. Remote verbinden + ersten Push

```bash
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/Programm/
git remote add origin https://github.com/Sparky32584/tus-gohfeld-mitgliederverwaltung.git
git branch -M main
git push -u origin main
```

Beim ersten Push fragt macOS nach GitHub-Credentials. Empfohlen:
**Personal Access Token (PAT)** mit Scope `repo`:

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. „Generate new token (classic)"
3. Name: `tus-gohfeld-macbook-sync`
4. Scope: nur `repo` anhaken
5. Generate → Token kopieren
6. Beim Git-Push-Prompt als Passwort eingeben
7. macOS-Keychain speichert es danach automatisch.

---

## Einrichtung auf dem MacBook (zweiter Mac)

### 1. Daten-Pfad vorbereiten

```bash
# iCloud-Ordner öffnen — die Datenbank sollte durch iCloud bereits da sein
open "$HOME/Library/Mobile Documents/com~apple~CloudDocs/TuS-Gohfeld-Daten"
```

Falls noch nichts drin ist: Warten bis iCloud fertig synchronisiert hat.

### 2. Code clonen

```bash
mkdir -p ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/
git clone https://github.com/Sparky32584/tus-gohfeld-mitgliederverwaltung.git Programm
cd Programm
```

### 3. Setup ausführen

```bash
./setup.sh
```

Bei der Abfrage nach dem Daten-Ordner: **Option 2 (iCloud)** wählen. So greifen
beide Macs auf dieselbe Datenbank zu.

### 4. Starten

```bash
./create-app.sh      # einmalig
open "$HOME/Applications/TuS Gohfeld.app"
```

---

## Täglicher Workflow

### Code-Änderungen auf Mac Mini → MacBook übertragen

**Auf dem Mac Mini** (nach Änderungen):

```bash
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/Programm/
git status
git add -A
git commit -m "Kurzbeschreibung der Änderung"
git push
```

**Auf dem MacBook**:

```bash
cd ~/Desktop/Vereine/TUS\ Gohfeld/Mitglieder/Programm/
git pull
```

Wenn `requirements.txt` sich geändert hat:
```bash
./venv/bin/pip install -r requirements.txt
```

### Konflikte vermeiden

| Ressource           | Synchronisation   | Regel                             |
|---------------------|-------------------|-----------------------------------|
| **Code** (.py/.html/.sh) | Git → GitHub | nach jeder Änderung pushen        |
| **Daten** (.db/Dokumente) | iCloud Drive | **nur ein Gerät gleichzeitig** öffnen |
| **Einstellungen** (settings.json) | iCloud Drive | folgt der Datenbank |
| **venv/**           | ignoriert         | auf jedem Mac einzeln installieren |

---

## Häufige Git-Befehle

```bash
# Was wurde geändert?
git status
git diff

# Letzte 10 Commits anzeigen
git log --oneline -10

# Datei aus dem letzten Commit wiederherstellen
git checkout -- pfad/zur/datei.py

# Letzten Commit rückgängig machen (lokal, noch nicht gepusht)
git reset --soft HEAD~1

# Remote-Änderungen einholen ohne zu mergen (Preview)
git fetch
git log origin/main..HEAD      # lokale Commits vor Push
git log HEAD..origin/main      # Remote-Commits, die noch nicht lokal sind
```

---

## Sicherheits-Checkliste

Vor jedem `git push` einmal prüfen, dass **keine Daten** hochgeladen werden:

```bash
git diff --cached --stat        # zeigt alle eingestagten Dateien
```

Wenn dort **eine** dieser Dateien auftaucht — **STOP**:

- `*.db` / `*.db-journal` / `*.db-wal` / `*.db-shm`
- `settings.json`
- `data/` / `Daten/` / `dokumente/` / `uploads/`
- `.env` / `.env.local`

Diese sind alle in `.gitignore`, sollten also **nie** in `git diff --cached`
erscheinen. Falls doch:

```bash
git reset HEAD pfad/zur/datei   # aus Staging entfernen
# dann prüfen, warum sie nicht ignoriert wurde
```

---

## Notfall: Versehentlich Daten gepusht

```bash
# 1. SOFORT vom Remote löschen
git rm --cached mitglieder.db
git commit -m "EMERGENCY: remove accidentally pushed DB"
git push

# 2. Aus History entfernen (erfordert force-push!)
# Nutzen Sie hierfür: git filter-repo oder BFG Repo-Cleaner
# https://rtyley.github.io/bfg-repo-cleaner/

# 3. Token am GitHub-Account rotieren
# 4. Allen Beteiligten Bescheid geben
```

Besser: Nie passieren lassen. `.gitignore` ist euer Freund.
