#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="$(plutil -extract CFBundleShortVersionString raw "$project_dir/Resources/Info.plist")"
dist_dir="$project_dir/dist"
dmg_name="CoolCharge-$version.dmg"
dmg_path="$dist_dir/$dmg_name"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/coolcharge-dmg.XXXXXX")"

cleanup() {
  if [[ -n "$staging_dir" && "$staging_dir" == *coolcharge-dmg.* ]]; then
    rm -rf "$staging_dir"
  fi
}
trap cleanup EXIT

zsh "$project_dir/Scripts/build-app.sh"
codesign --verify --deep --strict "$project_dir/CoolCharge.app"

mkdir -p "$dist_dir"
ditto "$project_dir/CoolCharge.app" "$staging_dir/CoolCharge.app"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
  -volname "CoolCharge" \
  -srcfolder "$staging_dir" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$dmg_path"

hdiutil verify "$dmg_path"
(
  cd "$dist_dir"
  shasum -a 256 "$dmg_name" > "$dmg_name.sha256"
)

echo "$dmg_path"
