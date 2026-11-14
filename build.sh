#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
OUTPUT_DIR="${NEWFILE_OUTPUT_DIR:-$PWD/dist}"
APP="$OUTPUT_DIR/NewFile.app"
EXT="$APP/Contents/PlugIns/NewFileFinder.appex"
REGISTER_APP="${NEWFILE_REGISTER_APP:-1}"
if [[ "${CI:-}" == "true" ]]; then REGISTER_APP=0; fi
mkdir -p "$APP/Contents/MacOS" "$EXT/Contents/MacOS" .build
source ./toolchain.sh
SIGNING_IDENTITY="${NEWFILE_SIGNING_IDENTITY:--}"
python3 Config/make_plists.py "$APP" "$EXT"
xcrun swiftc -O -target arm64-apple-macos13.0 "${SWIFT_FLAGS[@]}" \
  Sources/Localization.swift Sources/FileCreator.swift Sources/FinderMenuSettings.swift Sources/FinderRenamer.swift Sources/Settings.swift Sources/App.swift -o "$APP/Contents/MacOS/NewFile" -framework Cocoa -framework FinderSync -framework ApplicationServices
xcrun swiftc -O -target arm64-apple-macos13.0 "${SWIFT_FLAGS[@]}" \
  -parse-as-library -module-name NewFileFinder -application-extension Sources/Localization.swift Sources/FinderMenuSettings.swift Sources/FinderExtension.swift \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$EXT/Contents/MacOS/NewFileFinder" -framework Cocoa -framework FinderSync
ditto Resources "$APP/Contents/Resources"
ditto Resources "$EXT/Contents/Resources"
codesign --force --sign "$SIGNING_IDENTITY" --entitlements Config/Extension.entitlements "$EXT"
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
if [[ "$REGISTER_APP" == "1" ]]; then
  # TCC resolves permissions via the containing application's Launch Services
  # record, not just the extension's PlugInKit record.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
  # Preserve the user's enabled/disabled choice and the running process.
  if ! /usr/bin/pluginkit -a "$EXT"; then
    echo "Не удалось обновить регистрацию расширения. Откройте NewFile и настройки расширений Finder." >&2
  fi
fi
echo "Собрано: $APP"
