# Sourced by build.sh/test.sh. Keep any compatibility workaround local.
TOOLCHAIN_DIR="$(xcode-select -p)"
# Module caches embed absolute paths. Give each project location and compiler
# their own cache so a copied .build directory cannot break compilation.
CACHE_ID="$(python3 -c 'import hashlib, sys; print(hashlib.sha256("\n".join(sys.argv[1:]).encode()).hexdigest()[:16])' "$(pwd -P)" "$TOOLCHAIN_DIR" "$(xcrun swiftc --version 2>/dev/null)")"
MODULE_CACHE_ROOT="$PWD/.build/module-cache/$CACHE_ID"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$MODULE_CACHE_ROOT/swift"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"
SWIFT_FLAGS=(-module-cache-path "$SWIFT_MODULECACHE_PATH")
LEGACY_MAP="$TOOLCHAIN_DIR/usr/include/swift/module.modulemap"
CURRENT_MAP="$TOOLCHAIN_DIR/usr/include/swift/bridging.modulemap"
if [[ -f "$LEGACY_MAP" && -f "$CURRENT_MAP" ]] && python3 - "$LEGACY_MAP" "$CURRENT_MAP" <<'PY'
import pathlib, sys
def declarations(path):
    return '\n'.join(line.split('//')[0].strip() for line in pathlib.Path(path).read_text().splitlines() if line.split('//')[0].strip())
sys.exit(0 if declarations(sys.argv[1]) == declarations(sys.argv[2]) else 1)
PY
then
    mkdir -p .build/toolchain-overlay
    python3 - "$LEGACY_MAP" <<'PY'
import json, pathlib, sys
p = pathlib.Path('.build/toolchain-overlay').resolve()
(p / 'empty.modulemap').write_text('// Ignore a duplicate legacy SwiftBridging declaration.\n')
(p / 'overlay.json').write_text(json.dumps({'version': 0, 'roots': [
    {'type': 'file', 'name': sys.argv[1], 'external-contents': str(p / 'empty.modulemap')}
]}))
PY
    SWIFT_FLAGS+=(-vfsoverlay "$PWD/.build/toolchain-overlay/overlay.json")
fi
