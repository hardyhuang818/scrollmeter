#!/usr/bin/env bash
# Double-click to run the scroll smoothness benchmark.
#
# Fast paths (in order):
#   1. If a prebuilt `scrollmeter` binary is sitting here, use it directly —
#      no CLT, no compile. (Make one with build-universal.command.)
#   2. If CLT is installed, compile scrollmeter.swift on first run.
#   3. If CLT is missing but a Command Line Tools .pkg is in this folder,
#      install it locally with `sudo installer` (no Apple download).
#   4. Else trigger the online installer dialog.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "=============================================="
echo "  MacBook scroll smoothness benchmark"
echo "=============================================="
echo

chmod +x "${BASH_SOURCE[0]}" 2>/dev/null || true
[ -f scrollmeter ] && chmod +x scrollmeter 2>/dev/null || true

# --- Fast path: prebuilt binary, source missing or older --------------------
NEED_COMPILE=0
if [ ! -x ./scrollmeter ]; then
    NEED_COMPILE=1
elif [ -f scrollmeter.swift ] && [ scrollmeter.swift -nt ./scrollmeter ]; then
    NEED_COMPILE=1
fi

if [ "$NEED_COMPILE" = "0" ]; then
    echo "[ok] using prebuilt scrollmeter binary (no CLT required)"
    echo
    echo "Launching ScrollMeter window..."
    echo "  Scroll up/down on touchpad INSIDE the window for ~10s."
    echo
    ./scrollmeter
    echo
    echo "Done. Report saved to ~/Documents/scroll-bench/"
    read -n 1 -s -p "(press any key to close)"
    exit 0
fi

# --- We need to compile: find swiftc ----------------------------------------
CLT_SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
XCODE_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
XCODE_SWIFTC=""
if [ -n "$XCODE_DEV_DIR" ] && [ -x "$XCODE_DEV_DIR/usr/bin/swiftc" ]; then
    XCODE_SWIFTC="$XCODE_DEV_DIR/usr/bin/swiftc"
fi
INSTALL_RUNNING=0
if pgrep -x "Install Command Line Developer Tools" >/dev/null 2>&1; then
    INSTALL_RUNNING=1
fi
LOCAL_PKG=""
# Look for a CLT installer shipped alongside this script.
for cand in "Command Line Tools"*.pkg CommandLineTools*.pkg; do
    if [ -f "$cand" ]; then LOCAL_PKG="$cand"; break; fi
done

echo "[diag] xcode-select -p   : ${XCODE_DEV_DIR:-(not configured)}"
echo "[diag] CLT swiftc        : $([ -x "$CLT_SWIFTC" ] && echo yes || echo no)   $CLT_SWIFTC"
echo "[diag] Xcode swiftc      : ${XCODE_SWIFTC:-(none)}"
echo "[diag] install in progress: $([ "$INSTALL_RUNNING" = "1" ] && echo yes || echo no)"
echo "[diag] local CLT .pkg    : ${LOCAL_PKG:-(none)}"
echo

SWIFTC=""
if [ -x "$CLT_SWIFTC" ] && "$CLT_SWIFTC" --version >/dev/null 2>&1; then
    SWIFTC="$CLT_SWIFTC"
elif [ -n "$XCODE_SWIFTC" ] && "$XCODE_SWIFTC" --version >/dev/null 2>&1; then
    SWIFTC="$XCODE_SWIFTC"
fi

if [ -z "$SWIFTC" ]; then
    if [ "$INSTALL_RUNNING" = "1" ]; then
        echo "Xcode CLT installation is currently running."
        echo "Wait for the system installer to finish, then double-click this AGAIN."
    elif [ -n "$LOCAL_PKG" ]; then
        echo "Found local CLT installer: $LOCAL_PKG"
        echo "Installing offline (will ask for your password)..."
        echo
        if sudo installer -pkg "$LOCAL_PKG" -target /; then
            echo "[ok] CLT installed. Re-checking..."
            if [ -x "$CLT_SWIFTC" ] && "$CLT_SWIFTC" --version >/dev/null 2>&1; then
                SWIFTC="$CLT_SWIFTC"
            fi
        else
            echo "!! sudo installer failed."
        fi
    elif [ -x "$CLT_SWIFTC" ]; then
        echo "CLT binaries exist but the active toolchain is misconfigured."
        echo "Run this in Terminal (will ask for password), then re-run this script:"
        echo
        echo "    sudo xcode-select --switch /Library/Developer/CommandLineTools"
    else
        echo "Xcode Command Line Tools are not installed."
        echo
        echo ">> A system dialog should appear: click \"Install\", agree to license,"
        echo ">> wait ~5 minutes. When it FINISHES, double-click this AGAIN."
        echo
        echo "If no dialog appears, run in Terminal:  xcode-select --install"
        xcode-select --install 2>&1 | sed 's/^/    /' || true
    fi

    if [ -z "$SWIFTC" ]; then
        echo
        read -n 1 -s -p "(press any key to close this window)"
        exit 0
    fi
fi

echo "[ok] using swiftc: $SWIFTC"
echo "[ok] $("$SWIFTC" --version | head -1)"

# --- Compile -----------------------------------------------------------------
echo "[..] compiling scrollmeter..."
if ! "$SWIFTC" -O scrollmeter.swift -o scrollmeter; then
    echo
    echo "!! Build failed. See errors above."
    read -n 1 -s -p "(press any key to close)"
    exit 1
fi
echo "[ok] compiled"

# --- Run --------------------------------------------------------------------
echo
echo "Launching ScrollMeter window..."
echo "  1) Window auto-focuses"
echo "  2) Scroll up/down on touchpad INSIDE the window"
echo "  3) Recording lasts 10 seconds from the first scroll event"
echo "  4) Report prints here + saves to ~/Documents/scroll-bench/"
echo
./scrollmeter

echo
echo "Done. Compare runs by hitch ratio (ms/s) and coef of variation."
read -n 1 -s -p "(press any key to close)"
