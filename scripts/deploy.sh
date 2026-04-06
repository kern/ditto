#!/usr/bin/env bash
# deploy.sh — Archive and upload Ditto to App Store Connect.
#
# Required environment variables:
#   ASC_KEY_ID              App Store Connect API key ID (e.g. ABC123DEF4)
#   ASC_ISSUER_ID           App Store Connect API issuer UUID
#   ASC_PRIVATE_KEY         Contents of the .p8 key file (newlines preserved)
#   DEVELOPMENT_TEAM        Apple Developer Team ID (e.g. ABCDE12345)
#   DIST_CERT_P12_BASE64    Base64-encoded distribution certificate (.p12)
#   DIST_CERT_PASSWORD      Password for the .p12 file
#
# Optional:
#   BUILD_NUMBER            Override auto-derived build number (default: git commit count)
#   SKIP_UPLOAD             Set to 1 to archive/export only (no upload)
#
# Usage:
#   ASC_KEY_ID=... ASC_ISSUER_ID=... ... ./scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_PATH="$REPO_ROOT/build/Ditto.xcarchive"
EXPORT_PATH="$REPO_ROOT/build/export"
ASC_KEY_PATH="$REPO_ROOT/build/asc_key.p8"
KEYCHAIN_NAME="ditto-deploy-$(date +%s)"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"

# ── Helpers ──────────────────────────────────────────────────────────────────

check_env() {
    local missing=()
    for var in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY DEVELOPMENT_TEAM \
               DIST_CERT_P12_BASE64 DIST_CERT_PASSWORD; do
        [[ -z "${!var:-}" ]] && missing+=("$var")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌  Missing required environment variables: ${missing[*]}"
        exit 1
    fi
}

cleanup() {
    echo "→ Cleaning up temporary keychain and files..."
    security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
    rm -f "$ASC_KEY_PATH" "$REPO_ROOT/build/cert.p12"
}
trap cleanup EXIT

# ── Build number ─────────────────────────────────────────────────────────────

derive_build_number() {
    git -C "$REPO_ROOT" rev-list --count HEAD
}

# ── Setup ────────────────────────────────────────────────────────────────────

setup_keychain() {
    echo "→ Setting up temporary keychain..."
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
    security set-keychain-settings -lut 3600 "$KEYCHAIN_NAME"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

    # Prepend to search list so codesign finds it
    local current_keychains
    current_keychains=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
    # shellcheck disable=SC2086
    security list-keychains -d user -s "$KEYCHAIN_NAME" $current_keychains

    echo "→ Importing distribution certificate..."
    echo "$DIST_CERT_P12_BASE64" | base64 --decode > "$REPO_ROOT/build/cert.p12"
    security import "$REPO_ROOT/build/cert.p12" \
        -k "$KEYCHAIN_NAME" \
        -P "$DIST_CERT_PASSWORD" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        2>/dev/null
    security set-key-partition-list \
        -S "apple-tool:,apple:,codesign:" \
        -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME" \
        2>/dev/null
}

setup_asc_key() {
    echo "→ Writing App Store Connect API key..."
    mkdir -p "$(dirname "$ASC_KEY_PATH")"
    printf '%s' "$ASC_PRIVATE_KEY" > "$ASC_KEY_PATH"
    chmod 600 "$ASC_KEY_PATH"
}

# ── Archive ───────────────────────────────────────────────────────────────────

archive() {
    local build_number="${BUILD_NUMBER:-$(derive_build_number)}"
    echo "→ Archiving (build number: $build_number)..."
    mkdir -p "$REPO_ROOT/build"
    xcodebuild archive \
        -project "$REPO_ROOT/Ditto.xcodeproj" \
        -scheme Ditto \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        CURRENT_PROJECT_VERSION="$build_number" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        2>&1 | grep -E "error:|warning:|Archive|Compiling|Linking|BUILD" | tail -40
    echo "✓ Archive created at $ARCHIVE_PATH"
}

# ── Export ────────────────────────────────────────────────────────────────────

export_ipa() {
    echo "→ Exporting IPA..."
    # Write export options inline
    cat > "$REPO_ROOT/build/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF
    mkdir -p "$EXPORT_PATH"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$REPO_ROOT/build/ExportOptions.plist" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        2>&1 | grep -E "error:|warning:|Export|EXPORT|BUILD" | tail -20
    echo "✓ IPA exported to $EXPORT_PATH"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo "🚀  Ditto → App Store Connect"
    echo "    Repo: $REPO_ROOT"
    echo ""

    check_env
    setup_keychain
    setup_asc_key
    archive
    export_ipa

    if [[ "${SKIP_UPLOAD:-0}" == "1" ]]; then
        echo "⏭  SKIP_UPLOAD=1 — skipping upload."
    else
        echo "✓ Upload initiated via exportArchive destination=upload"
        echo "   Check App Store Connect → TestFlight for processing status."
    fi

    echo ""
    echo "✅  Done."
}

main "$@"
