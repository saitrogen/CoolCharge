#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/CoolCharge.app"
binary="$project_dir/.build/release/CoolCharge"
cache_root="${TMPDIR:-/tmp}/coolcharge-build-cache"

cd "$project_dir"
zsh "$project_dir/Scripts/generate-icon.sh"
mkdir -p "$cache_root/clang" "$cache_root/swiftpm"
env \
  CLANG_MODULE_CACHE_PATH="$cache_root/clang" \
  SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" \
  swift build -c release --disable-sandbox -Xswiftc -gnone

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/CoolCharge"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
xcrun actool \
  "$project_dir/Resources/Assets.xcassets" \
  --compile "$app_dir/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$cache_root/asset-info.plist" \
  >/dev/null
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
