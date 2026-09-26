#!/usr/bin/env python3
import json, pathlib, plistlib, re
root = pathlib.Path('ios-b2')
swift = '\n'.join(p.read_text() for p in (root / 'Sources').rglob('*.swift'))
for label, pattern in [('tab items', r'\.tabItem'), ('KeychainStore', r'kSecClassGenericPassword'), ('APNs registration', r'/api/auth/push-register'), ('deletion status', r'/api/auth/deletion-status'), ('request deletion', r'request-deletion'), ('cancel deletion', r'cancel-deletion'), ('domain whitelist', r'\["like-art.com", "www.like-art.com"\]'), ('UA', r'LikeArtApp/1.0'), ('native table', r'UITableView'), ('cookie store', r'httpCookieStore'), ('bridge', r'LikeAppNative')]:
    count = len(re.findall(pattern, swift))
    assert count > 0, label
    print(f'PASS {label}: {count}')

# A196: 底部菜单改为服务端配置驱动（/api/app-tabs），且必须有内置兜底默认值
assert 'AppTabsStore.shared' in swift, 'tabs store wiring'
assert 'api/app-tabs' in swift, 'tabs config api'
assert 'AppTabItem(key: "shop"' in swift, 'built-in tab fallback'
assert '.tabItem' in swift and 'ForEach' in swift, 'dynamic tab rendering'
assert 'tabIndex(for:' in swift, 'tab lookup by key (push/deeplink must survive reordering)'
print('PASS config-driven tab bar (app-tabs api + fallback + key-based lookup)')
info = plistlib.loads((root/'Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == 'Like Art'
assert info['ITSAppUsesNonExemptEncryption'] is False
assert len(info['UISupportedInterfaceOrientations~ipad']) == 4
for key in ['NSCameraUsageDescription', 'NSMicrophoneUsageDescription', 'NSFaceIDUsageDescription']:
    assert len(info[key].split(' / ')) == 3
assert (root/'Resources/Base.lproj/LaunchScreen.storyboard').exists()
privacy = plistlib.loads((root/'Resources/PrivacyInfo.xcprivacy').read_bytes())
assert not privacy['NSPrivacyTracking'] and not privacy['NSPrivacyTrackingDomains']
assert len(privacy['NSPrivacyCollectedDataTypes']) == 9
icons=json.loads((root/'Resources/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())['images']
for size in [76,152,167,1024]:
    assert any(x['filename']==f'icon-{size}.png' for x in icons)
print('PASS source Info.plist, three languages, launch screen, privacy manifest and all iPad icon sizes')

# ENTRY207: check archive, descriptor, Swift anchors and Info.plist together.
import hashlib, zipfile
meta = json.loads((root/'Resources/v6-pack.json').read_text())
pak = root/'Resources/v6-base-assets.pak'
assert pak.stat().st_size == meta['bytes']
assert hashlib.sha256(pak.read_bytes()).hexdigest() == meta['sha256']
with zipfile.ZipFile(pak) as archive:
    assert json.loads(archive.read('manifest.json'))['version'] == meta['version']
    assert all(e.compress_type == zipfile.ZIP_STORED for e in archive.infolist())
assert f'expectedSize: Int64 = {meta["bytes"]}' in swift
assert f'packVersion = "{meta["version"]}"' in swift
assert f'packSHA256 = "{meta["sha256"]}"' in swift
assert info['V6PackVersion'] == meta['version']
assert info['V6PackSize'] == meta['bytes']
assert info['V6PackSHA256'] == meta['sha256']
for symbol in ['setURLSchemeHandler', 'WorldPack.shared', 'PackShim.script', 'preparationLock', 'verifyChecksum(fileURL)']:
    assert symbol in swift, symbol
print('PASS bundled archive/descriptor/Swift/Info.plist contract')
