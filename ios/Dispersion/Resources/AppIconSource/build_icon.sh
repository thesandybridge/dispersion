#!/usr/bin/env bash
# Builds the Dispersion app icon family.
#
# Generates one .appiconset per palette, with three appearance variants
# per palette (light / dark / tinted) so the icon plays nicely with iOS 18
# Home Screen customization (light, dark, and tint modes).
#
# Run: bash build_icon.sh
#
# Output goes directly into the AppIcon + alternate appiconsets under
# ../Assets.xcassets so XcodeGen / Xcode picks them up next build.

set -euo pipefail

cd "$(dirname "$0")"

ASSETS_DIR="../Assets.xcassets"

# ─── Palette definitions ─────────────────────────────────────────────
# Background gradient, contour, flag. Geometry matches BrandMark.svg.
palette_pine=("1f6147" "0a2e1f" "f6f1e1" "a9d18e")
palette_sand=("9c8458" "30281a" "f6f1e1" "decb98")
palette_sunset=("9b5a3a" "2a1a14" "f6f1e1" "ecb586")
palette_slate=("5a6878" "14181f" "f6f1e1" "c5d0db")

PALETTES=(pine sand sunset slate)

# Asset-catalog folder names (one per palette). pine IS AppIcon (the primary).
iconset_for() {
  case "$1" in
    pine)   echo "AppIcon" ;;
    sand)   echo "AppIcon-Sand" ;;
    sunset) echo "AppIcon-Sunset" ;;
    slate)  echo "AppIcon-Slate" ;;
  esac
}

# ─── Per-palette renderers ───────────────────────────────────────────

render_mark() {
  local out=$1 bg_inner=$2 bg_outer=$3 contour=$4 flag=$5
  magick -size 1024x1024 gradient:"#${bg_inner}-#${bg_outer}" \
    -fill none -stroke "#${contour}" -strokewidth 32 \
    -draw "ellipse 512,665 348,195 0,360" \
    -draw "ellipse 512,665 235,123 0,360" \
    -stroke none -fill "#${flag}" \
    -draw "roundrectangle 486,205 538,676 26,26" \
    -draw "polygon 512,205 788,317 512,430" \
    -strip -alpha off "${out}"
}

render_light() {
  local out=$1; shift
  render_mark "$out" "$1" "$2" "$3" "$4"
}

render_dark() {
  local out=$1; shift
  render_mark "$out" "$(darken "$1" 0.45)" "$(darken "$2" 0.45)" "$3" "$4"
}

render_tinted() {
  render_mark "$1" "080808" "000000" "cccccc" "ffffff"
}

# ─── Helpers ─────────────────────────────────────────────────────────

# Multiply each channel of a hex color by `factor` (0..1).
darken() {
  local h=$1 factor=$2
  local r g b
  r=$((16#${h:0:2}))
  g=$((16#${h:2:2}))
  b=$((16#${h:4:2}))
  printf "%02x%02x%02x" \
    "$(awk "BEGIN{print int(${r}*${factor})}")" \
    "$(awk "BEGIN{print int(${g}*${factor})}")" \
    "$(awk "BEGIN{print int(${b}*${factor})}")"
}

# Write the Contents.json for an appiconset with three appearances.
write_contents_json() {
  local dir=$1
  cat > "${dir}/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon_dark_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon_tinted_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

# ─── Main ────────────────────────────────────────────────────────────

for name in "${PALETTES[@]}"; do
  set_name=$(iconset_for "${name}")
  out_dir="${ASSETS_DIR}/${set_name}.appiconset"
  mkdir -p "${out_dir}"

  echo "→ ${name} → ${out_dir}"

  case "${name}" in
    pine)   render_light "${out_dir}/icon_1024.png"      "${palette_pine[@]}"
            render_dark  "${out_dir}/icon_dark_1024.png" "${palette_pine[@]}" ;;
    sand)   render_light "${out_dir}/icon_1024.png"      "${palette_sand[@]}"
            render_dark  "${out_dir}/icon_dark_1024.png" "${palette_sand[@]}" ;;
    sunset) render_light "${out_dir}/icon_1024.png"      "${palette_sunset[@]}"
            render_dark  "${out_dir}/icon_dark_1024.png" "${palette_sunset[@]}" ;;
    slate)  render_light "${out_dir}/icon_1024.png"      "${palette_slate[@]}"
            render_dark  "${out_dir}/icon_dark_1024.png" "${palette_slate[@]}" ;;
  esac

  # Tinted variant doesn't depend on palette colors (it's monochrome).
  render_tinted "${out_dir}/icon_tinted_1024.png"

  write_contents_json "${out_dir}"
done

# Generate Asset Catalog imagesets for the in-app icon picker (so settings UI
# can show a tile per palette). One imageset per palette: IconPreview-<Name>.
write_preview_imageset() {
  local name=$1
  local cap=$(tr '[:lower:]' '[:upper:]' <<< "${name:0:1}")${name:1}
  local set_name=$(iconset_for "${name}")
  local source="${ASSETS_DIR}/${set_name}.appiconset/icon_1024.png"
  local target_dir="${ASSETS_DIR}/IconPreview-${cap}.imageset"
  mkdir -p "${target_dir}"
  # Render @1x, @2x, @3x so the preview tile stays crisp on every device class.
  magick "${source}" -resize 60x60 "${target_dir}/preview-1.png"
  magick "${source}" -resize 120x120 "${target_dir}/preview-2.png"
  magick "${source}" -resize 180x180 "${target_dir}/preview-3.png"
  cat > "${target_dir}/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "preview-1.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "preview-2.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "preview-3.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
}

for name in "${PALETTES[@]}"; do
  write_preview_imageset "${name}"
done

# Local-disk preview grid for visual sanity checks (gitignored).
preview_dir="previews"
mkdir -p "${preview_dir}"
for name in "${PALETTES[@]}"; do
  set_name=$(iconset_for "${name}")
  out_dir="${ASSETS_DIR}/${set_name}.appiconset"
  magick "${out_dir}/icon_1024.png" -resize 180x180 "${preview_dir}/${name}_180.png"
done

# Keep the companion icon in step with the primary iPhone icon.
watch_icons="../../../DispersionWatch/Assets.xcassets/AppIcon.appiconset"
if [ -d "$watch_icons" ]; then
  cp "${ASSETS_DIR}/AppIcon.appiconset/icon_1024.png" "$watch_icons/icon_1024.png"
  cp "${ASSETS_DIR}/AppIcon.appiconset/icon_dark_1024.png" "$watch_icons/icon_dark_1024.png"
  cp "${ASSETS_DIR}/AppIcon.appiconset/icon_tinted_1024.png" "$watch_icons/icon_tinted_1024.png"
fi

echo "✓ Built ${#PALETTES[@]} palettes (${#PALETTES[@]} × 3 appearances)"
ls -la "${preview_dir}"
