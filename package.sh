#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION="$(python3 Config/version.py)"
OUTPUT_DIR="${NEWFILE_PACKAGE_DIR:-$PWD/release}"
mkdir -p .build "$OUTPUT_DIR"
STAGING="$(mktemp -d "$PWD/.build/package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ARCHIVE="NewFile-$VERSION-macOS-arm64.zip"
bash test.sh
NEWFILE_OUTPUT_DIR="$STAGING/dist" NEWFILE_REGISTER_APP=0 bash build.sh

PACKAGE="$STAGING/NewFile"
mkdir -p "$PACKAGE/Source"
ditto "$STAGING/dist/NewFile.app" "$PACKAGE/NewFile.app"
cp README.md "$PACKAGE/README.md"
cp -R docs Artwork "$PACKAGE/"
cp README.md VERSION .gitignore build.sh test.sh toolchain.sh package.sh "$PACKAGE/Source/"
cp -R Sources Config Tests Resources docs Artwork .github "$PACKAGE/Source/"
find "$PACKAGE/Source" -type d -name __pycache__ -prune -exec rm -rf {} +
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE" "$STAGING/$ARCHIVE"

mv "$STAGING/$ARCHIVE" "$OUTPUT_DIR/$ARCHIVE"
(cd "$OUTPUT_DIR" && LC_ALL=C shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
echo "Готово: $OUTPUT_DIR/$ARCHIVE"
