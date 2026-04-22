#!/usr/bin/env bash
# Build MarkdownObserver (this fork) and install it to /Applications/.
#
# Usage (from the repo root):
#   ./scripts/install.sh
#
# What it does:
#   1. Runs xcodebuild Release with the fork-specific Bundle ID override
#   2. Copies the built .app to /Applications/MarkdownObserver-Fork.app
#   3. Optionally appends a shell alias if `--alias` is passed
#
# Flags:
#   --alias    Append `alias mdo='open -a MarkdownObserver-Fork'` to ~/.zshrc
#              if it isn't already there.
#   --debug    Build Debug instead of Release.
#   --help     Show this help.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MarkdownObserver-Fork.app"
APP_DEST="/Applications/${APP_NAME}"
BUNDLE_ID="com.github.branch10480.markdownobserver.fork"
CONFIGURATION="Release"
ADD_ALIAS=0

for arg in "$@"; do
  case "$arg" in
    --alias) ADD_ALIAS=1 ;;
    --debug) CONFIGURATION="Debug" ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown flag $arg" >&2
      exit 2
      ;;
  esac
done

echo "==> Resolving Swift package dependencies"
(cd "$REPO_ROOT" && xcodebuild -resolvePackageDependencies \
  -project minimark.xcodeproj -scheme minimark >/dev/null)

echo "==> Building $CONFIGURATION"
BUILD_DIR="${REPO_ROOT}/build"
(cd "$REPO_ROOT" && xcodebuild \
  -project minimark.xcodeproj \
  -scheme minimark \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  "APP_BUNDLE_IDENTIFIER=${BUNDLE_ID}" \
  "TESTS_BUNDLE_IDENTIFIER=${BUNDLE_ID}.tests" \
  "UITESTS_BUNDLE_IDENTIFIER=${BUNDLE_ID}.uitests" \
  CODE_SIGN_IDENTITY= \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null)

SRC_APP="${BUILD_DIR}/Build/Products/${CONFIGURATION}/MarkdownObserver.app"
if [[ ! -d "$SRC_APP" ]]; then
  echo "error: expected app not found at $SRC_APP" >&2
  exit 1
fi

echo "==> Installing to $APP_DEST"
if [[ -d "$APP_DEST" ]]; then
  rm -rf "$APP_DEST"
fi
cp -R "$SRC_APP" "$APP_DEST"

if [[ $ADD_ALIAS -eq 1 ]]; then
  ZSHRC="${HOME}/.zshrc"
  ALIAS_LINE="alias mdo='open -a MarkdownObserver-Fork'"
  if ! grep -Fqs "$ALIAS_LINE" "$ZSHRC" 2>/dev/null; then
    {
      echo ""
      echo "# Added by markdownobserver fork install.sh"
      echo "$ALIAS_LINE"
    } >>"$ZSHRC"
    echo "==> Added alias to $ZSHRC (reload your shell: exec zsh)"
  else
    echo "==> alias already present in $ZSHRC"
  fi
fi

echo ""
echo "Installed: $APP_DEST"
echo "Launch:    open -a MarkdownObserver-Fork path/to/file.md"
echo "Customize: ~/Library/Application Support/MarkdownObserver/themes/user.css"
