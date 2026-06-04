#!/usr/bin/env bash
# Run this ONCE on a Mac that has Xcode CLT installed.
# Produces a `scrollmeter` binary suitable for distribution.
#
# Ideal output: universal (arm64 + x86_64). But some CLT downloads (e.g.
# *_Apple_silicon.dmg) ship only the ARM stdlib, in which case we fall back
# to a single-arch binary and tell you what happened.
#
# Min deployment target = the host macOS (no explicit -target pin), so you
# need to build on a Mac whose OS is <= the OS of the machines you ship to.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"

CLT_SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
XCODE_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
SWIFTC=""
if [ -x "$CLT_SWIFTC" ] && "$CLT_SWIFTC" --version >/dev/null 2>&1; then
    SWIFTC="$CLT_SWIFTC"
elif [ -n "$XCODE_DEV_DIR" ] && [ -x "$XCODE_DEV_DIR/usr/bin/swiftc" ]; then
    SWIFTC="$XCODE_DEV_DIR/usr/bin/swiftc"
fi
if [ -z "$SWIFTC" ]; then
    echo "Xcode CLT not found. Run run-bench.command first to install."
    read -n 1 -s -p "(press any key to close)"
    exit 1
fi
echo "[ok] swiftc: $SWIFTC"
echo "[ok] $("$SWIFTC" --version | head -1)"
echo "[ok] host arch: $(uname -m)"
echo

HAVE_ARM=0
HAVE_X86=0

echo "[..] building arm64 slice..."
if "$SWIFTC" -O -arch arm64 scrollmeter.swift -o .scrollmeter_arm64 2>&1 \
        | sed 's/^/    /'; then
    [ -f .scrollmeter_arm64 ] && HAVE_ARM=1
fi
[ "$HAVE_ARM" = "1" ] && echo "    -> ok" || echo "    -> FAILED"

echo "[..] building x86_64 slice..."
if "$SWIFTC" -O -arch x86_64 scrollmeter.swift -o .scrollmeter_x86_64 2>&1 \
        | sed 's/^/    /'; then
    [ -f .scrollmeter_x86_64 ] && HAVE_X86=1
fi
[ "$HAVE_X86" = "1" ] && echo "    -> ok" || \
    echo "    -> FAILED (likely Apple-Silicon-only CLT; install the universal CLT dmg if you need Intel support)"

echo
rm -f scrollmeter
if [ "$HAVE_ARM" = "1" ] && [ "$HAVE_X86" = "1" ]; then
    lipo -create -output scrollmeter .scrollmeter_arm64 .scrollmeter_x86_64
    echo "[ok] universal binary written: scrollmeter"
elif [ "$HAVE_ARM" = "1" ]; then
    mv .scrollmeter_arm64 scrollmeter
    echo "[ok] arm64-only binary written (Apple Silicon Macs only)"
elif [ "$HAVE_X86" = "1" ]; then
    mv .scrollmeter_x86_64 scrollmeter
    echo "[ok] x86_64-only binary written (Intel Macs only)"
else
    echo "!! Both slices failed to build. See errors above."
    rm -f .scrollmeter_arm64 .scrollmeter_x86_64
    read -n 1 -s -p "(press any key to close)"
    exit 1
fi
rm -f .scrollmeter_arm64 .scrollmeter_x86_64
chmod +x scrollmeter

echo
echo "Result:"
file scrollmeter | sed 's/^/    /'
echo "Size: $(du -h scrollmeter | cut -f1)"
echo
echo "Distribution: ship these files to the target Mac(s):"
echo "    scrollmeter        (the binary)"
echo "    run-bench.command  (the launcher)"
echo "    README.md"
echo
read -n 1 -s -p "(press any key to close)"
