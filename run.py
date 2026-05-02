#!/usr/bin/env python3
"""
TuS Gohfeld Mitgliederverwaltung — Native macOS Launcher
=========================================================

Startet den Flask-Server im Hintergrund und öffnet ein pywebview-Fenster,
damit das Programm wie eine native Desktop-App aussieht.

Besonderheiten:
- Stellt sicher, dass /opt/homebrew/bin (Tesseract, Poppler) im PATH ist
- Sucht freien Port ab 5000
- Wartet auf Server-Bereitschaft bevor das Fenster erscheint
- Ordnet Daten-Verzeichnis bevorzugt über TUS_DATA_DIR zu
- Fängt Fehler ab und zeigt sie als Dialog
"""

from __future__ import annotations

import os
import sys
import socket
import threading
import time
import traceback
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# 1) PATH erweitern — Homebrew-Binaries (Tesseract, Poppler) finden
# ---------------------------------------------------------------------------
# Reihenfolge: Homebrew (Apple Silicon) > Homebrew (Intel) > bestehender PATH
_HOMEBREW_PATHS = ["/opt/homebrew/bin", "/usr/local/bin"]
_existing = os.environ.get("PATH", "").split(":")
_new_path = [p for p in _HOMEBREW_PATHS if p not in _existing] + _existing
os.environ["PATH"] = ":".join(_new_path)

# ---------------------------------------------------------------------------
# 2) Arbeits­verzeichnis auf Skript-Ordner setzen (wichtig für .app-Bundle)
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
os.chdir(SCRIPT_DIR)
sys.path.insert(0, str(SCRIPT_DIR))

# ---------------------------------------------------------------------------
# 2b) .env.local laden (TUS_DATA_DIR setzen)
# ---------------------------------------------------------------------------
_env_file = SCRIPT_DIR / ".env.local"
if _env_file.exists():
    with open(_env_file) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                os.environ.setdefault(_k.strip(), _v.strip().strip('"\''))

# ---------------------------------------------------------------------------
# 3) Freien Port finden
# ---------------------------------------------------------------------------
def find_free_port(start: int = 5000, end: int = 5050) -> int:
    for port in range(start, end + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise RuntimeError(f"Kein freier Port im Bereich {start}–{end}")


# ---------------------------------------------------------------------------
# 4) Flask-Server in Hintergrund-Thread starten
# ---------------------------------------------------------------------------
def start_flask(port: int) -> None:
    # Import erst hier, damit PATH-Änderungen aus (1) greifen
    from app import app  # noqa: WPS433

    # Werkzeug-Dev-Server deaktiviert den Reloader automatisch, wenn er
    # nicht im Haupt­thread läuft — genau das wollen wir.
    app.run(
        host="127.0.0.1",
        port=port,
        debug=False,
        use_reloader=False,
        threaded=True,
    )


def wait_for_server(url: str, timeout: float = 15.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as resp:
                if resp.status == 200:
                    return True
        except Exception:  # noqa: BLE001
            pass
        time.sleep(0.25)
    return False


# ---------------------------------------------------------------------------
# 5) Fehlerdialog (falls etwas schiefgeht)
# ---------------------------------------------------------------------------
def show_error(title: str, message: str) -> None:
    """Fallback-Dialog per AppleScript (keine zusätzlichen Abhängigkeiten)."""
    try:
        import subprocess

        esc = message.replace('"', '\\"').replace("\n", "\\n")
        subprocess.run(
            [
                "osascript",
                "-e",
                f'display dialog "{esc}" with title "{title}" buttons {{"OK"}} '
                f'default button "OK" with icon stop',
            ],
            check=False,
        )
    except Exception:  # noqa: BLE001
        print(f"[{title}] {message}", file=sys.stderr)


# ---------------------------------------------------------------------------
# 6) Main
# ---------------------------------------------------------------------------
def main() -> None:
    try:
        port = find_free_port()
        url = f"http://127.0.0.1:{port}"

        # Datenbank initialisieren
        from app import init_db  # noqa: WPS433
        init_db()

        # Flask-Thread starten
        flask_thread = threading.Thread(
            target=start_flask,
            args=(port,),
            daemon=True,
            name="tus-flask",
        )
        flask_thread.start()

        # Auf Server-Bereitschaft warten
        if not wait_for_server(url):
            show_error(
                "TuS Gohfeld — Serverfehler",
                "Der interne Webserver konnte nicht gestartet werden.\n"
                "Bitte prüfen Sie die Installation (setup.sh ausführen).",
            )
            sys.exit(1)

        # pywebview-Fenster öffnen
        import webview  # noqa: WPS433

        webview.create_window(
            title="TuS Gohfeld — Mitgliederverwaltung",
            url=url,
            width=1400,
            height=900,
            min_size=(1000, 700),
            resizable=True,
            text_select=True,
            confirm_close=False,
        )
        webview.start(gui="cocoa", debug=False)

    except ImportError as exc:
        show_error(
            "TuS Gohfeld — Abhängigkeit fehlt",
            f"Ein benötigtes Python-Paket ist nicht installiert:\n{exc}\n\n"
            "Bitte ausführen:\n./setup.sh",
        )
        sys.exit(1)
    except Exception:  # noqa: BLE001
        show_error(
            "TuS Gohfeld — Unerwarteter Fehler",
            traceback.format_exc(),
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
