#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source_icon="$project_dir/Resources/AppIcon-master.png"
iconset_dir="$project_dir/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$iconset_dir"

render_icon() {
  local pixels="$1"
  local filename="$2"
  sips -z "$pixels" "$pixels" "$source_icon" --out "$iconset_dir/$filename" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

echo "$iconset_dir"
