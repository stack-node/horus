#!/usr/bin/env bash
# Build the anubis-halo helper and copy it next to the Horus binary (same directory as
# `swift build --show-bin-path` for this package) so HaloLauncher can find it via sibling lookup.
set -euo pipefail

CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "usage: $0 [debug|release]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HORUS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANUBIS_ROOT="$(cd "$HORUS_ROOT/../anubis-halo" && pwd)"

if [[ ! -f "$ANUBIS_ROOT/Package.swift" ]]; then
  echo "error: expected anubis-halo at: $ANUBIS_ROOT" >&2
  exit 1
fi

echo "Building anubis-halo ($CONFIG)…"
( cd "$ANUBIS_ROOT" && swift build -c "$CONFIG" --product anubis-halo )

echo "Resolving build directories…"
SRC_BIN="$(cd "$ANUBIS_ROOT" && swift build -c "$CONFIG" --show-bin-path)/anubis-halo"
DST_DIR="$(cd "$HORUS_ROOT" && swift build -c "$CONFIG" --show-bin-path)"
DST_BIN="$DST_DIR/anubis-halo"

if [[ ! -x "$SRC_BIN" ]]; then
  echo "error: missing helper binary: $SRC_BIN" >&2
  exit 1
fi

mkdir -p "$DST_DIR"
cp -f "$SRC_BIN" "$DST_BIN"
chmod +x "$DST_BIN"

echo "Copied anubis-halo → $DST_BIN"
