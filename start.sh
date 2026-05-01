#!/bin/bash
# =============================================================================
# TuS Gohfeld — Start im Terminal (Browser-Variante)
# =============================================================================
# Startet nur den Flask-Server. Der Browser wird manuell unter
# http://127.0.0.1:5000 geöffnet. Nützlich zum Testen oder wenn pywebview
# Probleme macht.
#
# Für native App-Variante stattdessen run.py verwenden.
# =============================================================================

cd "$(dirname "$0")"

# Homebrew-PATH für OCR-Tools sicherstellen
if [ -d "/opt/homebrew/bin" ] && ! echo "$PATH" | grep -q "/opt/homebrew/bin"; then
    export PATH="/opt/homebrew/bin:$PATH"
fi
if [ -d "/usr/local/bin" ] && ! echo "$PATH" | grep -q "/usr/local/bin"; then
    export PATH="/usr/local/bin:$PATH"
fi

# .env.local (falls vorhanden) einlesen — setzt TUS_DATA_DIR
if [ -f ".env.local" ]; then
    # shellcheck disable=SC1091
    source .env.local
fi

# Fallback: wenn noch nicht gesetzt, Default auf iCloud
if [ -z "$TUS_DATA_DIR" ]; then
    export TUS_DATA_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/TuS-Gohfeld-Daten"
fi
mkdir -p "$TUS_DATA_DIR"

# venv prüfen
if [ ! -d "venv" ]; then
    echo "❌ venv/ nicht gefunden. Bitte zuerst ./setup.sh ausführen."
    exit 1
fi

echo ""
echo "=========================================================="
echo "  TuS Gohfeld — Mitgliederverwaltung"
echo "=========================================================="
echo "  Daten-Ordner : $TUS_DATA_DIR"
echo "  Browser-URL  : http://127.0.0.1:5000"
echo "  Beenden      : Strg+C"
echo "=========================================================="
echo ""

# Browser nach 2s öffnen (im Hintergrund)
(sleep 2 && open "http://127.0.0.1:5000") &

# Flask-Server starten (blockierend)
exec ./venv/bin/python3 app.py
