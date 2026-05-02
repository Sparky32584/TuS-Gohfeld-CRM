#!/bin/bash
# =============================================================================
# TuS Gohfeld — macOS .app-Bundle erzeugen
# =============================================================================
# Erstellt ~/Applications/TuS Gohfeld.app, die im Dock erscheint und per
# Doppelklick die Mitgliederverwaltung als native Fenster startet.
#
# Das Bundle enthält NUR einen Launcher, der auf den eigentlichen Projekt-
# Ordner verweist. Updates am Code sind sofort wirksam — kein Re-Bundling nötig.
# =============================================================================

set -e
cd "$(dirname "$0")"

# ---- Konfiguration ----
APP_NAME="TuS Mitgliederverwaltung"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
PROJECT_DIR="$(pwd)"
BUNDLE_ID="de.tus-gohfeld.mitgliederverwaltung"

# ---- Farben ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✓  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }

echo ""
echo "=========================================================="
echo "  TuS Gohfeld — .app-Bundle erzeugen"
echo "=========================================================="
echo ""

# ---- venv prüfen ----
if [ ! -d "venv" ]; then
    warn "venv/ nicht gefunden. Bitte zuerst ./setup.sh ausführen."
    exit 1
fi

# ---- Alte App entfernen ----
if [ -d "$APP_DIR" ]; then
    warn "Existiert bereits: $APP_DIR"
    read -rp "   Überschreiben? [j/N] " yn
    if [[ ! "$yn" =~ ^[Jj] ]]; then
        echo "Abgebrochen."
        exit 0
    fi
    rm -rf "$APP_DIR"
fi

# ---- Bundle-Struktur anlegen ----
info "Erstelle Bundle-Struktur …"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# ---- Info.plist ----
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

# ---- Launcher-Skript ----
cat > "$APP_DIR/Contents/MacOS/launcher" <<EOF
#!/bin/bash
# Generiert durch create-app.sh am $(date)
cd "${PROJECT_DIR}"

# Laufende Instanz beenden
lsof -ti:5000 -ti:5001 | xargs kill -9 2>/dev/null

# .env.local einlesen (für TUS_DATA_DIR)
if [ -f ".env.local" ]; then
    source .env.local
fi

# Homebrew-PATH
if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:\$PATH"
fi
if [ -d "/usr/local/bin" ]; then
    export PATH="/usr/local/bin:\$PATH"
fi

# Start
exec ./venv/bin/python3 run.py
EOF
chmod +x "$APP_DIR/Contents/MacOS/launcher"

# ---- Icon: Logo aus static/ kopieren und in .icns konvertieren (falls vorhanden) ----
if [ -f "static/logo.png" ]; then
    info "Erzeuge App-Icon aus static/logo.png …"
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    # Alle erforderlichen Icon-Größen generieren
    for size in 16 32 64 128 256 512 1024; do
        sips -z "$size" "$size" "static/logo.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1 || true
    done
    # @2x-Varianten
    cp "$ICONSET_DIR/icon_32x32.png"     "$ICONSET_DIR/icon_16x16@2x.png"   2>/dev/null || true
    cp "$ICONSET_DIR/icon_64x64.png"     "$ICONSET_DIR/icon_32x32@2x.png"   2>/dev/null || true
    cp "$ICONSET_DIR/icon_256x256.png"   "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_512x512.png"   "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null || true
    rm -f "$ICONSET_DIR/icon_64x64.png" "$ICONSET_DIR/icon_1024x1024.png"

    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null && \
        success "Icon erzeugt" || warn "iconutil fehlgeschlagen, Standard-Icon wird verwendet"

    rm -rf "$(dirname "$ICONSET_DIR")"
else
    warn "static/logo.png nicht gefunden — Bundle ohne eigenes Icon"
fi

# ---- LaunchServices aktualisieren, damit Finder das neue App-Icon lädt ----
touch "$APP_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_DIR" >/dev/null 2>&1 || true

echo ""
echo "=========================================================="
success ".app-Bundle erzeugt:"
echo "   $APP_DIR"
echo ""
echo "Optional ins Dock legen:"
echo "   open \"$HOME/Applications\""
echo "   und dann \"${APP_NAME}\" per Drag ins Dock ziehen."
echo "=========================================================="
echo ""
