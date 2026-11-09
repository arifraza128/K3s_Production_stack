#!/usr/bin/env bash
# ==============================================================================
# Phase 8 — Timed Disaster Recovery (DR) Drill Runner (DATABASE.md §6 Schema)
# Usage: bash scripts/dr-drill.sh [full-destroy|db-corruption|backup-corruption]
# ==============================================================================
set -euo pipefail

exec bash "$(dirname "$0")/../../scripts/dr-drill.sh" "$@"
