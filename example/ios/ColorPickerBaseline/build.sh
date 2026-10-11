#!/usr/bin/env bash
# Compile the standalone simulator control arm; do not boot or install anything.
set -euo pipefail

baseline_sources="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
baseline_example="$(cd -- "$baseline_sources/../.." && pwd)"
baseline_output="$baseline_example/build/color-picker-baseline/ColorPickerBaseline.app"
baseline_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"

mkdir -p "$baseline_output"
cp "$baseline_sources/Info.plist" "$baseline_output/Info.plist"
xcrun --sdk iphonesimulator swiftc \
  -parse-as-library -emit-executable -Onone -g \
  -module-name ColorPickerBaseline \
  -sdk "$baseline_sdk" -target arm64-apple-ios16.0-simulator \
  -framework UIKit \
  "$baseline_sources/ColorPickerBaseline.swift" \
  -o "$baseline_output/ColorPickerBaseline"
codesign --force --sign - --timestamp=none "$baseline_output"
printf '%s\n' "$baseline_output"
