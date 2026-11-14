#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
source ./toolchain.sh
ditto Resources .build
xcrun swiftc "${SWIFT_FLAGS[@]}" Sources/Localization.swift Sources/FileCreator.swift Tests/FileCreatorTests.swift -o .build/FileCreatorTests
.build/FileCreatorTests
xcrun swiftc "${SWIFT_FLAGS[@]}" Sources/Localization.swift Sources/FileCreator.swift Sources/FinderMenuSettings.swift Sources/FinderRenamer.swift Sources/Settings.swift Tests/SettingsTests.swift -o .build/SettingsTests -framework SwiftUI -framework ApplicationServices
.build/SettingsTests
