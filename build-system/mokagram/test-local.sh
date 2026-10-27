#!/bin/bash
# Runs one Bazel test target in the simulator with the same placeholder signing as build-local.sh.
# Usage: build-system/mokagram/test-local.sh //submodules/TelegramCore:TelegramCoreTests
set -euo pipefail
cd "$(dirname "$0")/../.."

TARGET="${1:?usage: $0 <bazel test label>}"
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
  test \
  --configurationPath=build-input/mokagram/configuration.json \
  --codesigningInformationPath=build-input/mokagram/signing \
  --target "$TARGET"
