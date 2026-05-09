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

# ─── Geometry (shared across palettes) ────────────────────────────────
W=1024
H=1024
CX=$((W / 2))
CY=540   # slightly low — leaves headroom for the flag

# Heat-ellipse rings (rx, ry) — outer → inner, then center bullseye.
# Same shape across palettes, only colors change.
RINGS=(
  "465 380"
  "395 320"
  "320 258"
  "245 196"
  "170 135"
  "95 74"
  "38 30"
)

# Pin geometry constants
PIN_TOP=$((CY - 220))
PIN_TOP_FLAG=$((CY - 200))
PIN_BOT_FLAG=$((CY - 180))

# ─── Palette definitions ─────────────────────────────────────────────
# Each palette is a list of:
#   bg_inner bg_outer  ring1 ring2 ring3 ring4 ring5 ring6 ring7  shaft  flag
# All as hex colors (no #).

palette_pine=(
  "1f6147" "0a2e1f"
  "0b3d2e" "165e4a" "2d8a5e" "62b375" "a9d18e" "f0e7b8" "fff7d6"
  "f6f1e1" "e85d4d"
)

palette_sand=(
  "9c8458" "30281a"
  "5a4a30" "7d6740" "a18957" "c4a872" "decb98" "f0e3b9" "fff5d6"
  "f6f1e1" "1f6147"
)

palette_sunset=(
  "9b5a3a" "2a1a14"
  "5c2a1d" "8c4a35" "b06a48" "d18860" "ecb586" "f7d4a3" "ffe9c8"
  "f6f1e1" "0a2618"
)

palette_slate=(
  "5a6878" "14181f"
  "2c3a4a" "4a5867" "6f7e8d" "9da9b5" "c5d0db" "e3eaf1" "f3f6f8"
  "f6f1e1" "e85d4d"
)

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

render_light() {
  local out=$1; shift
  local bg_inner=$1 bg_outer=$2
  local rings=("$3" "$4" "$5" "$6" "$7" "$8" "$9")
  local shaft=${10} flag=${11}

  # Base radial gradient
  magick -size ${W}x${H} radial-gradient:"#${bg_inner}-#${bg_outer}" .work.png

  # Heat ellipses, outer → inner. Alpha rises slightly toward the center
  # for a more dimensional feel.
  local alphas=(0.78 0.86 0.90 0.93 0.95 1.00 1.00)
  for i in "${!RINGS[@]}"; do
    read -r rx ry <<< "${RINGS[$i]}"
    local a=${alphas[$i]}
    magick .work.png \
      -fill "rgba($(hex_rgb ${rings[$i]}),${a})" \
      -draw "ellipse ${CX},${CY} ${rx},${ry} 0,360" \
      .work.png
  done

  # Subtle vignette
  magick -size ${W}x${H} radial-gradient:'rgba(0,0,0,0)-rgba(0,0,0,0.20)' .vig.png
  magick .work.png .vig.png -compose over -composite .work.png

  # Pin
  magick .work.png \
    -fill "#0a2618" -stroke "#${shaft}" -strokewidth 6 \
    -draw "ellipse ${CX},${CY} 22,10 0,360" \
    -stroke none \
    -fill "#${shaft}" \
    -draw "roundrectangle $((CX - 7)),${PIN_TOP} $((CX + 7)),${CY} 6,6" \
    -fill "#${flag}" \
    -draw "polygon $((CX + 7)),${PIN_TOP} $((CX + 130)),${PIN_TOP_FLAG} $((CX + 7)),${PIN_BOT_FLAG}" \
    .work.png

  magick .work.png -strip -background "#${bg_outer}" -alpha remove -alpha off "${out}"
  rm -f .vig.png
}

# Dark variant: same palette, but darkened bg + brighter foreground for
# legibility on dark home screens. Apple may composite over a dark
# wallpaper-aware area, so we keep an opaque bg (still recommended).
render_dark() {
  local out=$1; shift
  local bg_inner=$1 bg_outer=$2
  local rings=("$3" "$4" "$5" "$6" "$7" "$8" "$9")
  local shaft=${10} flag=${11}

  # Darken the bg by ~50%
  local dk_inner; dk_inner=$(darken "${bg_inner}" 0.55)
  local dk_outer; dk_outer=$(darken "${bg_outer}" 0.40)

  magick -size ${W}x${H} radial-gradient:"#${dk_inner}-#${dk_outer}" .work.png

  local alphas=(0.55 0.66 0.74 0.84 0.92 1.00 1.00)
  for i in "${!RINGS[@]}"; do
    read -r rx ry <<< "${RINGS[$i]}"
    local a=${alphas[$i]}
    magick .work.png \
      -fill "rgba($(hex_rgb ${rings[$i]}),${a})" \
      -draw "ellipse ${CX},${CY} ${rx},${ry} 0,360" \
      .work.png
  done

  magick -size ${W}x${H} radial-gradient:'rgba(0,0,0,0)-rgba(0,0,0,0.30)' .vig.png
  magick .work.png .vig.png -compose over -composite .work.png

  magick .work.png \
    -fill "#000000" -stroke "#${shaft}" -strokewidth 6 \
    -draw "ellipse ${CX},${CY} 22,10 0,360" \
    -stroke none \
    -fill "#${shaft}" \
    -draw "roundrectangle $((CX - 7)),${PIN_TOP} $((CX + 7)),${CY} 6,6" \
    -fill "#${flag}" \
    -draw "polygon $((CX + 7)),${PIN_TOP} $((CX + 130)),${PIN_TOP_FLAG} $((CX + 7)),${PIN_BOT_FLAG}" \
    .work.png

  magick .work.png -strip -background "#${dk_outer}" -alpha remove -alpha off "${out}"
  rm -f .vig.png
}

# Tinted variant: monochrome silhouette that iOS will recolor with the
# user's chosen tint. Background is BLACK; foreground is grayscale white,
# brightness varying to imply depth. (iOS uses the luminance of the image
# to drive the tint mapping.)
render_tinted() {
  local out=$1

  magick -size ${W}x${H} xc:'#000000' .work.png

  # Heat ellipses as grayscale (outer dim → inner bright)
  local grays=(2a 3c 55 76 9c c8 ee)
  local alphas=(0.40 0.55 0.70 0.85 0.95 1.00 1.00)
  for i in "${!RINGS[@]}"; do
    read -r rx ry <<< "${RINGS[$i]}"
    local g=${grays[$i]} a=${alphas[$i]}
    magick .work.png \
      -fill "rgba($(hex_rgb ${g}${g}${g}),${a})" \
      -draw "ellipse ${CX},${CY} ${rx},${ry} 0,360" \
      .work.png
  done

  # Pin in white
  magick .work.png \
    -fill "#000000" -stroke "#ffffff" -strokewidth 6 \
    -draw "ellipse ${CX},${CY} 22,10 0,360" \
    -stroke none \
    -fill "#ffffff" \
    -draw "roundrectangle $((CX - 7)),${PIN_TOP} $((CX + 7)),${CY} 6,6" \
    -draw "polygon $((CX + 7)),${PIN_TOP} $((CX + 130)),${PIN_TOP_FLAG} $((CX + 7)),${PIN_BOT_FLAG}" \
    .work.png

  magick .work.png -strip -background '#000000' -alpha remove -alpha off "${out}"
}

# ─── Helpers ─────────────────────────────────────────────────────────

# hex → "r,g,b" decimal triplet for use inside rgba()
hex_rgb() {
  local h=$1
  echo "$((16#${h:0:2})),$((16#${h:2:2})),$((16#${h:4:2}))"
}

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

# Tidy
rm -f .work.png

echo "✓ Built ${#PALETTES[@]} palettes (${#PALETTES[@]} × 3 appearances)"
ls -la "${preview_dir}"
