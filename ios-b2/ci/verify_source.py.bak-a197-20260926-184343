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
