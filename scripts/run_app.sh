#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$("$ROOT/scripts/build_app.sh")"
killall MatrixTetris >/dev/null 2>&1 || true
sleep 0.2
open "$APP"
