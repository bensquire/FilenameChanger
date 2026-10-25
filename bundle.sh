#!/bin/zsh
# Build FilenameChanger.app from the SwiftPM executable.
#
# Env overrides (used by CI):
#   VERSION           marketing version (default 0.1.0)
#   CODESIGN_IDENTITY signing identity ("-" for ad-hoc; default: local
#                     Developer ID)
set -e
cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"
# "SOUIRE" is how the certificate itself spells it (as in PaperPress).
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: BENJAMIN RICHARD SOUIRE (SZHK3JVH6J)}"

swift build -c release -Xswiftc -Osize
APP=FilenameChanger.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/FilenameChanger $APP/Contents/MacOS/
strip -rSTx $APP/Contents/MacOS/FilenameChanger
cp icon/FilenameChanger.icns $APP/Contents/Resources/
# Info.plist lives as a real file (editor tooling, lintable) with the
# version templated in.
sed "s/@VERSION@/${VERSION}/" scripts/Info.plist.template \
    > $APP/Contents/Info.plist
plutil -lint -s $APP/Contents/Info.plist
codesign --force --options runtime --timestamp --sign "$IDENTITY" $APP
codesign --verify --strict --deep $APP
echo "built and signed $PWD/$APP (v$VERSION)"
