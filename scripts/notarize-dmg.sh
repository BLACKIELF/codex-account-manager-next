#!/usr/bin/env bash
set -euo pipefail

: "${DMG_PATH:?DMG_PATH is required}"
: "${APPLE_ID:?APPLE_ID is required}"
: "${TEAM_ID:?TEAM_ID is required}"
: "${NOTARY_PASSWORD:?NOTARY_PASSWORD is required}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$NOTARY_PASSWORD" \
  --wait

xcrun stapler staple "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"
