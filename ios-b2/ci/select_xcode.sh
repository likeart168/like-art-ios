#!/bin/bash
set -euo pipefail
mkdir -p build-b2/evidence
xcodebuild -version | tee build-b2/evidence/xcode-default.txt
selected=$(find /Applications -maxdepth 1 -type d -name 'Xcode_26*.app' | sort -V | tail -1)
if [ -z "$selected" ]; then
  echo 'Xcode 26.x is required. Available installations:'
  find /Applications -maxdepth 1 -name 'Xcode*.app'
  exit 1
fi
sudo xcode-select -s "$selected/Contents/Developer"
xcodebuild -version | tee build-b2/evidence/xcode-version.txt
xcodebuild -version | head -1 | grep -E '^Xcode 26\.'
echo "DEVELOPER_DIR=$selected/Contents/Developer" >> "$GITHUB_ENV"
echo "BUILD_NUMBER=$(date -u +%Y%m%d%H%M)" >> "$GITHUB_ENV"
