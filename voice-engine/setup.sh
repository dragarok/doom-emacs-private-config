#!/bin/sh
# Build hear and put its model in place, on the machine that will run it
# (Termux on the phone, macOS on the Mac).  M-x voice-engine-setup runs it.
#   HEAR_DIR   where models live (default ~/.local/share/hear)
#   HEAR_SEED  what a Mac pushed over adb, used when there (default /sdcard/Download/hear-model):
#              hear (a prebuilt binary, for a phone without clang) and phonon-2.5/
set -e
cd "$(dirname "$0")"
DIR=${HEAR_DIR:-$HOME/.local/share/hear}
SEED=${HEAR_SEED:-/sdcard/Download/hear-model}
mkdir -p "$DIR"

built=
if command -v cc >/dev/null 2>&1 && command -v make >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
  echo "building hear"
  if make; then built=1; else echo "the build failed"; fi
fi
if [ -z "$built" ]; then
  if [ -f "$SEED/hear" ]; then
    echo "using the prebuilt hear from $SEED"
    cp "$SEED/hear" ./hear
    chmod 755 ./hear
  else
    echo "no compiler and no prebuilt hear: pkg install clang make git" >&2
    exit 1
  fi
fi

if [ ! -f "$DIR/phonon-2.5/weights.bin" ]; then
  if [ -f "$SEED/phonon-2.5/weights.bin" ]; then
    echo "model from $SEED"
    mkdir -p "$DIR/phonon-2.5.tmp"
    cp "$SEED/phonon-2.5/weights.bin" "$SEED/phonon-2.5/weights.json" "$SEED/phonon-2.5/tokens.txt" "$DIR/phonon-2.5.tmp/"
    mv "$DIR/phonon-2.5.tmp" "$DIR/phonon-2.5"
  else
    echo "downloading the model (183 MB)"
    make weights MODELS="$DIR"
  fi
fi
./hear file "$DIR/phonon-2.5" /dev/null >/dev/null 2>&1 || true
echo "ready: $DIR/phonon-2.5"
