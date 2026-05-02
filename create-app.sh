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

# ---- AppleScript-App via osacompile erzeugen ----
# Grund: macOS akzeptiert AppleScript-Apps zuverlässig (keine Gatekeeper-Blockade
# wie bei unsignierten C-Binaries oder Bash-Launchern).
info "Erzeuge AppleScript-App …"
osacompile -o "$APP_DIR" -e 'do shell script (quoted form of (POSIX path of (path to me)) & "Contents/Resources/run-app.sh")' || {
    warn "osacompile fehlgeschlagen"
    exit 1
}

# ---- Shell-Launcher in Bundle-Resources schreiben ----
LAUNCH_SH="$APP_DIR/Contents/Resources/run-app.sh"
cat > "$LAUNCH_SH" <<'SHELLEOF'
#!/bin/bash
mkdir -p ~/Library/Logs
LOG=~/Library/Logs/TuS-Mitgliederverwaltung.log
echo "[Launcher] start $(date)" > "$LOG"
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
lsof -ti:5000 -ti:5001 | xargs kill -9 >/dev/null 2>&1
cd "__PROJECT_DIR__" 2>>"$LOG" || { echo "cd failed" >> "$LOG"; exit 1; }
echo "[Launcher] starte Python …" >> "$LOG"
nohup ./venv/bin/python3 run.py >> "$LOG" 2>&1 &
SHELLEOF
sed -i '' "s|__PROJECT_DIR__|${PROJECT_DIR}|" "$LAUNCH_SH"
chmod +x "$LAUNCH_SH"

# ---- Info.plist patchen (Name, Identifier, Icon) ----
PLIST="$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :NSHighResolutionCapable true" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$PLIST"
# Standard applet.icns entfernen (unser Icon ersetzt es)
rm -f "$APP_DIR/Contents/Resources/applet.icns"

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
