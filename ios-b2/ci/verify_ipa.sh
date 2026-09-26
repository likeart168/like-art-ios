#!/bin/bash
set -euo pipefail
ipa=$(find build-b2/export -name '*.ipa' -maxdepth 1 -print -quit)
test -n "$ipa"
unzip -l "$ipa" | tee build-b2/evidence/ipa-contents.txt
mkdir -p build-b2/verify
unzip -q "$ipa" -d build-b2/verify
app=build-b2/verify/Payload/LikeArt.app
test -s "$app/LikeArt"
test -s "$app/Assets.car"
test -s "$app/PrivacyInfo.xcprivacy"
test -d "$app/Base.lproj/LaunchScreen.storyboardc"
test ! -e "$app/__preview.gif"
# A197: V6 基础资源包必须进 .app 且字节数一致（安卓 APK 同款验收）
test -s "$app/v6-base-assets.pak"
python3 - "$app" <<'PYCODE'
import sys, pathlib, json, hashlib, plistlib, zipfile
app = pathlib.Path(sys.argv[1]); meta = json.loads((app/'v6-pack.json').read_text()); pak = app/'v6-base-assets.pak'
assert pak.stat().st_size == meta['bytes']
assert hashlib.sha256(pak.read_bytes()).hexdigest() == meta['sha256']
assert plistlib.loads((app/'Info.plist').read_bytes())['V6PackVersion'] == meta['version']
with zipfile.ZipFile(pak) as archive: assert json.loads(archive.read('manifest.json'))['version'] == meta['version']
PYCODE
shasum -a 256 "$app/v6-base-assets.pak" | tee build-b2/evidence/pak-sha256.txt

plutil -lint "$app/Info.plist" "$app/PrivacyInfo.xcprivacy"
plutil -p "$app/Info.plist" | tee build-b2/evidence/ipa-info-plist.txt
plutil -p "$app/PrivacyInfo.xcprivacy" | tee build-b2/evidence/privacy-manifest.txt
for lang in en zh-Hans ru; do
  plutil -p "$app/$lang.lproj/InfoPlist.strings" | tee "build-b2/evidence/permissions-$lang.txt"
done
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Info.plist")" = "$BUILD_NUMBER"
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$app/Info.plist")" = 'Like Art'
codesign --verify --deep --strict --verbose=2 "$app" 2>&1 | tee build-b2/evidence/codesign-verify.txt
codesign -d --entitlements :- "$app" > build-b2/evidence/signed-entitlements.plist 2> build-b2/evidence/codesign-details.txt
shasum -a 256 "$ipa" | tee build-b2/evidence/ipa-sha256.txt
file "$app/LikeArt" | tee build-b2/evidence/executable.txt
