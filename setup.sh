#!/bin/bash
# =============================================================================
# TuS Gohfeld Mitgliederverwaltung — Setup-Skript (macOS)
# =============================================================================
# Führt folgende Schritte aus:
#   1. Prüft Python 3 (benötigt 3.10+)
#   2. Prüft/installiert Homebrew-Tools (tesseract, poppler) für OCR
#   3. Legt virtuelles Environment (venv/) an
#   4. Installiert alle Python-Abhängigkeiten aus requirements.txt
#   5. Lässt den Benutzer den Daten-Ordner wählen (lokal vs. iCloud)
#   6. Erstellt eine TUS_DATA_DIR-Konfigurationsdatei
# =============================================================================

set -e   # Bei Fehler sofort abbrechen
cd "$(dirname "$0")"

# ---- Farben für hübschere Ausgabe ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✓  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
fail()    { echo -e "${RED}✗  $*${NC}"; exit 1; }

echo ""
echo "================================================================"
echo "  TuS Gohfeld — Mitgliederverwaltung — Setup"
echo "================================================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Python 3 prüfen
# -----------------------------------------------------------------------------
info "Prüfe Python 3 …"
if ! command -v python3 >/dev/null 2>&1; then
    fail "Python 3 nicht gefunden. Bitte installieren: https://www.python.org/downloads/"
fi

PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)

# Minimum: Python 3.9 (getestet auf 3.9.6 und 3.11)
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 9 ]; }; then
    fail "Python $PY_VERSION ist zu alt. Mindestens Python 3.9 erforderlich."
fi
success "Python $PY_VERSION gefunden"

# -----------------------------------------------------------------------------
# 2. Homebrew + OCR-Tools
# -----------------------------------------------------------------------------
info "Prüfe Homebrew …"
if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew nicht gefunden."
    echo "   Soll Homebrew jetzt installiert werden? (empfohlen für OCR)"
    read -rp "   [j/N] " yn
    if [[ "$yn" =~ ^[Jj] ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Für Apple Silicon PATH erweitern
        if [ -d "/opt/homebrew/bin" ] && ! echo "$PATH" | grep -q "/opt/homebrew/bin"; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        warn "OCR wird ohne Homebrew NICHT funktionieren. Weiter ohne OCR-Tools."
    fi
fi

if command -v brew >/dev/null 2>&1; then
    info "Prüfe OCR-Tools (tesseract, poppler) …"
    if ! brew list tesseract >/dev/null 2>&1; then
        info "Installiere tesseract …"
        brew install tesseract tesseract-lang
    else
        success "tesseract installiert"
    fi
    if ! brew list poppler >/dev/null 2>&1; then
        info "Installiere poppler (für pdf2image) …"
        brew install poppler
    else
        success "poppler installiert"
    fi
fi

# -----------------------------------------------------------------------------
# 3. Virtuelles Environment
# -----------------------------------------------------------------------------
if [ -d "venv" ]; then
    warn "venv/ existiert bereits."
    read -rp "   Neu anlegen (venv löschen)? [j/N] " yn
    if [[ "$yn" =~ ^[Jj] ]]; then
        rm -rf venv
    fi
fi

if [ ! -d "venv" ]; then
    info "Lege virtuelles Environment an …"
    python3 -m venv venv
    success "venv erstellt"
fi

# -----------------------------------------------------------------------------
# 4. Pip-Pakete
# -----------------------------------------------------------------------------
info "Aktualisiere pip …"
./venv/bin/pip install --quiet --upgrade pip setuptools wheel

info "Installiere Python-Abhängigkeiten (kann 1-2 Minuten dauern) …"
./venv/bin/pip install --quiet -r requirements.txt
success "Alle Pakete installiert"

# -----------------------------------------------------------------------------
# 5. Daten-Ordner wählen
# -----------------------------------------------------------------------------
echo ""
info "Wo sollen die Mitgliederdaten gespeichert werden?"
echo ""
echo "  1) Lokal im Projekt-Ordner ($(pwd)/data)"
echo "     → Einfach, aber nur auf diesem Mac verfügbar"
echo ""
echo "  2) iCloud Drive (empfohlen für Mac-Mini + MacBook-Setup)"
echo "     → Automatische Synchronisation zwischen Geräten"
echo "     → Pfad: ~/Library/Mobile Documents/com~apple~CloudDocs/TuS-Gohfeld-Daten"
echo ""
echo "  3) Eigener Pfad"
echo ""
read -rp "   Auswahl [1-3] (Standard: 2): " choice
choice="${choice:-2}"

case "$choice" in
    1)
        DATA_DIR="$(pwd)/data"
        ;;
    2)
        DATA_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/TuS-Gohfeld-Daten"
        ;;
    3)
        read -rp "   Vollständiger Pfad: " DATA_DIR
        ;;
    *)
        fail "Ungültige Auswahl"
        ;;
esac

mkdir -p "$DATA_DIR"
success "Datenverzeichnis: $DATA_DIR"

# -----------------------------------------------------------------------------
# 6. .env-Datei schreiben
# -----------------------------------------------------------------------------
cat > .env.local <<EOF
# Automatisch erzeugt durch setup.sh am $(date)
# Wird von start.sh und run.py ausgelesen
export TUS_DATA_DIR="$DATA_DIR"
EOF
success ".env.local geschrieben"

# -----------------------------------------------------------------------------
# Fertig
# -----------------------------------------------------------------------------
echo ""
echo "================================================================"
success "Setup abgeschlossen!"
echo "================================================================"
echo ""
echo "Nächste Schritte:"
echo "  • Start im Terminal:        ./start.sh"
echo "  • Start als Native-App:     python3 run.py"
echo "  • .app-Bundle erzeugen:     ./create-app.sh"
echo ""
