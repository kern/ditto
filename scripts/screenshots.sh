#!/usr/bin/env bash
# screenshots.sh — Capture App Store screenshots and upload to App Store Connect.
#
# Usage:
#   ./scripts/screenshots.sh             # capture + upload
#   SKIP_UPLOAD=1 ./scripts/screenshots.sh   # capture only
#
# Required env vars for upload (same as deploy.sh):
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "📸  Ditto Screenshots"
echo ""

# ── Capture ───────────────────────────────────────────────────────────────────

echo "→ Capturing screenshots on simulator..."
fastlane snapshot

echo ""
echo "✓ Screenshots saved to fastlane/screenshots/"

# ── Upload ────────────────────────────────────────────────────────────────────

if [[ "${SKIP_UPLOAD:-0}" == "1" ]]; then
    echo "⏭  SKIP_UPLOAD=1 — skipping upload."
    echo ""
    echo "✅  Done. Open fastlane/screenshots/screenshots.html to preview."
    exit 0
fi

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_PRIVATE_KEY:-}" ]]; then
    echo "⚠️   ASC credentials not set — skipping upload."
    echo "    Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY to also upload."
    exit 0
fi

echo "→ Uploading screenshots to App Store Connect..."
fastlane upload_screenshots

echo ""
echo "✅  Done. Check App Store Connect to review the uploaded screenshots."
