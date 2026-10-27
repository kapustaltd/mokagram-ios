#!/bin/bash
# Local release IPA build, the same steps as .github/workflows/build.yml.
# The result is unsigned for distribution: re-sign it with your Apple ID before installing.
# Optional: TELEGRAM_API_ID and TELEGRAM_API_HASH (set both) for your own API pair.
# Optional: CONFIGURATION (default release_arm64), BUILD_NUMBER (default 1).
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIGURATION="${CONFIGURATION:-release_arm64}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
KEYCHAIN="$(mktemp -d)/mokagram.keychain-db"
ORIGINAL_KEYCHAINS="$(security list-keychains -d user | tr -d '"' | xargs)"

cleanup() {
  # shellcheck disable=SC2086
  security list-keychains -d user -s $ORIGINAL_KEYCHAINS || true
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -rf build-input/mokagram
}
trap cleanup EXIT

python3 build-system/mokagram/prepare.py

security create-keychain -p placeholder "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p placeholder "$KEYCHAIN"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $ORIGINAL_KEYCHAINS
security import build-input/mokagram/signing/certs/Placeholder.p12 \
  -k "$KEYCHAIN" -P placeholder -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -k placeholder "$KEYCHAIN" >/dev/null

python3 -u build-system/Make/Make.py \
  --overrideXcodeVersion \
  --cacheDir="$HOME/telegram-bazel-cache" \
  build \
  --configurationPath=build-input/mokagram/configuration.json \
  --codesigningInformationPath=build-input/mokagram/signing \
  --configuration="$CONFIGURATION" \
  --buildNumber="$BUILD_NUMBER"

mkdir -p build/artifacts
rm -f build/artifacts/Mokagram-unsigned.ipa
cp bazel-bin/Telegram/Telegram.ipa build/artifacts/Mokagram-unsigned.ipa
shasum -a 256 build/artifacts/Mokagram-unsigned.ipa > build/artifacts/Mokagram-unsigned.ipa.sha256
echo "Done: $(pwd)/build/artifacts/Mokagram-unsigned.ipa"
