#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
package_version=$(awk '/^version:[[:space:]]/ { print $2 }' pubspec.yaml)
if [[ -z "$package_version" || "$package_version" == *$'\n'* ]]; then
  echo "Expected one package version in pubspec.yaml." >&2
  exit 1
fi

for podspec in ios/*.podspec; do
  pod_version=$(sed -nE "s/^[[:space:]]*[[:alnum:]_]+\\.version[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"][[:space:]]*$/\\1/p" "$podspec")
  if [[ "$pod_version" != "$package_version" ]]; then
    echo "$podspec version '$pod_version' does not match pubspec.yaml version '$package_version'." >&2
    exit 1
  fi
done
