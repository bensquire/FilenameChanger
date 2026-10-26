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

# The Shortcuts actions' metadata, Contents/Resources/Metadata.appintents,
# made as Xcode's "Extract App Intents Metadata" phase makes it (SwiftPM has
# no such phase): RenameApp, which declares the actions, to its own
# Metadata.appintents, then the executable, which merges RenameApp's in.
# Without it Shortcuts never sees the actions. Before `strip`: the processor
# reads the symbols. The flags --binary-file and --compile-time-extraction
# don't appear in --help; they're what Xcode 27.1 passes.
extract_app_intents_metadata() {
    local toolchain sdk xcode_build deployment inter work bundle_id
    toolchain=$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain
    sdk=$(xcrun --sdk macosx --show-sdk-path)
    xcode_build=$(xcodebuild -version | awk '/Build version/ {print $3}')
    deployment=$(plutil -extract LSMinimumSystemVersion raw scripts/Info.plist.template)
    bundle_id=$(plutil -extract CFBundleIdentifier raw scripts/Info.plist.template)
    inter=.build/out/Intermediates.noindex/FilenameChanger.build/Release
    work=.build/appintents
    rm -rf $work
    mkdir -p $work
    : > $work/empty.list
    extract() {  # module, objects folder, binary, output folder, libraries' metadata list
        local objects=$2
        ls $objects/*.swiftconstvalues > $work/$1.constvalues.list
        $toolchain/usr/bin/appintentsmetadataprocessor \
            --toolchain-dir $toolchain --module-name $1 --sdk-root $sdk \
            --xcode-version $xcode_build --platform-family macOS \
            --deployment-target $deployment --bundle-identifier $bundle_id \
            --target-triple arm64-apple-macos$deployment \
            --binary-file $3 --output $4 \
            --dependency-file $work/$1.dependency_info.dat --stringsdata-file $work/$1.stringsdata \
            --source-file-list $objects/$1.SwiftFileList --metadata-file-list $work/empty.list \
            --static-metadata-file-list $5 --swift-const-vals-list $work/$1.constvalues.list \
            --force --compile-time-extraction --deployment-aware-processing \
            --no-app-shortcuts-localization > /dev/null
    }
    extract RenameApp $inter/RenameApp-t.build/Objects-normal/arm64 .build/release/RenameApp.o \
        $work/RenameApp $work/empty.list
    echo $PWD/$work/RenameApp/Metadata.appintents/extract.actionsdata > $work/libraries.list
    extract FilenameChanger $inter/FilenameChanger-p.build/Objects-normal/arm64 \
        .build/release/FilenameChanger $APP/Contents/Resources $work/libraries.list
}

# -emit-const-values: swiftc also writes the .swiftconstvalues the App
# Intents metadata step reads (Xcode passes the same two flags). The
# protocol list is the one Xcode 27.1 generates; refresh it with Xcode.
swift build -c release -Xswiftc -Osize \
    -Xswiftc -emit-const-values \
    -Xswiftc -const-gather-protocols-list -Xswiftc "$PWD/scripts/const_extract_protocols.json"
APP=FilenameChanger.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/FilenameChanger $APP/Contents/MacOS/
extract_app_intents_metadata
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
