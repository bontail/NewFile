import pathlib
import plistlib
import sys
import os
import re

from version import read_version

app, ext = map(pathlib.Path, sys.argv[1:])
build_number = os.environ.get("NEWFILE_BUILD_NUMBER", "4")
if not re.fullmatch(r"[1-9][0-9]*", build_number):
    raise SystemExit("NEWFILE_BUILD_NUMBER must be a positive integer")
base = dict(CFBundleDevelopmentRegion="en", CFBundleInfoDictionaryVersion="6.0",
            CFBundleLocalizations=["en", "ru", "de", "fr", "es", "it", "pt", "uk", "zh-Hans", "ja"],
            CFBundleShortVersionString=read_version(), CFBundleVersion=build_number, LSMinimumSystemVersion="13.0")
host = dict(base, CFBundleIdentifier="local.codex.newfile", CFBundleExecutable="NewFile",
            CFBundleName="NewFile", CFBundleDisplayName="NewFile", CFBundlePackageType="APPL",
            NSPrincipalClass="NSApplication", NSHighResolutionCapable=True,
            CFBundleURLTypes=[dict(CFBundleURLName="local.codex.newfile.create", CFBundleURLSchemes=["local-newfile"])])
plugin = dict(base, CFBundleIdentifier="local.codex.newfile.finder", CFBundleExecutable="NewFileFinder",
              CFBundleName="NewFile Finder", CFBundleDisplayName="NewFile Finder", CFBundlePackageType="XPC!",
              NSExtension=dict(NSExtensionAttributes={}, NSExtensionPointIdentifier="com.apple.FinderSync",
                               NSExtensionPrincipalClass="NewFileFinderExtension"))
for destination, content in [(app, host), (ext, plugin)]:
    (destination / "Contents" / "Info.plist").write_bytes(plistlib.dumps(content))
    (destination / "Contents" / "PkgInfo").write_bytes((content["CFBundlePackageType"] + "????").encode())
