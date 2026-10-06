#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP='dist/小龙娘桌宠.app'
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist/build
if [[ "${DRAGONPET_ARCH:-universal}" == native ]]; then
  BUILD_ARCHES=("$(uname -m)")
else
  BUILD_ARCHES=(arm64 x86_64)
fi
for BUILD_ARCH in "${BUILD_ARCHES[@]}"; do
  swiftc Sources/*.swift -O -target "$BUILD_ARCH-apple-macosx13.0" -sdk "$SDK_PATH" -framework AppKit -framework Security -framework ServiceManagement -o "dist/build/DragonPet-$BUILD_ARCH"
done
if (( ${#BUILD_ARCHES[@]} == 2 )); then
  lipo -create dist/build/DragonPet-arm64 dist/build/DragonPet-x86_64 -output "$APP/Contents/MacOS/DragonPet"
else
  cp "dist/build/DragonPet-${BUILD_ARCHES[1]}" "$APP/Contents/MacOS/DragonPet"
fi
cp -R Resources/Skins "$APP/Contents/Resources/"
cp -R Resources/Companion "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${DRAGONPET_BUNDLE_ID:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $DRAGONPET_BUNDLE_ID" "$APP/Contents/Info.plist"
fi
swift scripts/make-icon.swift "$PWD/dist/build/DragonPet.iconset"
iconutil -c icns dist/build/DragonPet.iconset -o "$APP/Contents/Resources/DragonPet.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
