# Like Art native iOS shell

SwiftUI application, iOS 16+, bundle `com.likeart.app`, four tabs matching Android B2A. XcodeGen generates the project; no Capacitor/DCloud dependencies are used by this target.

## Build

```sh
xcodegen generate --spec ios-b2/project.yml
xcodebuild -project ios-b2/LikeArt.xcodeproj -scheme LikeArt -sdk iphoneos -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Push `ios-b2/**` or `.github/workflows/build-b2.yml` to `b2-native-shell`, or dispatch **B2 Native iOS — Xcode 26**. The workflow selects an installed Xcode 26.x, compiles the asset catalog, builds unsigned, imports signing credentials, archives/signs, exports an App Store IPA, and retains it **before** attempting ASC upload. Version is 1.0.0; build number is the UTC minute timestamp. Workflow runs are serialized.

Existing secret names: `P12_CERTIFICATE`, `P12_PASSWORD`, `PROVISIONING_PROFILE`, `AUTHKEY_BASE64`, `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`. Signing can use the distribution certificate/profile already tracked by the original repository and its documented password. No private key is added by B2. ASC requires the current key in `AUTHKEY_BASE64`; the known fallback identifiers are RA48U82CSV and issuer 8ad4234e-2fc0-4943-8cde-e8bff3541efb. No JWT or P8 content is printed.

IPA and stdout are GitHub artifacts retained 30 days. Public, non-secret stdout is also committed by CI to `b2-build-evidence` under `docs/app-store-launch/ci/<run-id>/`. Always inspect `summary.txt` and `asc-build.json`: `continue-on-error` deliberately allows a green build when the separately recorded upload has failed. Only an exact-build `processingState: VALID` establishes ASC acceptance.

## Native behavior

- Native launch storyboard, navigation/tab bars, loading/error/offline UI; web failures never remove the native shell.
- HTTPS navigation restricted to `like-art.com` and `www.like-art.com`; other main-frame links open the system browser. Native bridge is main-frame and origin restricted. User agent includes `LikeArtApp/1.0`; shop/world include `app=1`.
- Web `auth_token` is validated by `/api/auth/me` and stored in Keychain. Native requests share WKWebView cookies; API redirects are refused to prevent forwarding JWTs to another origin. Logout clears website session data and Keychain.
- Optional biometric sign-in stores a separate `.biometryCurrentSet` protected Keychain item, removes the unprotected credential, and gates all content on next launch. Existing JWT is reused; no undocumented refresh endpoint is invented.
- Native UITableView combines `/api/auth/notifications` (404 fallback `/api/social/notifications`, as used by Android) and per-account JSON push history. Account/points/messages persist locally with file protection.
- Profile loads `/api/auth/me`, `/dw-dev/api/points/balance`, and independently `/api/auth/deletion-status`. Request/cancel use confirmation, a 30-day explanation, a live countdown, and subsequent status fetch. All native text has Chinese/English/Russian variants.
- APNs registration posts `/api/auth/push-register`; no sender is implemented. The supplied profile must have `aps-environment` to enable real APNs. Existing profile lacks it; CI records this instead of inventing an entitlement.
- Share sheet and inbound URL routing are implemented. Actual Universal Links require an associated-domains capable profile and a website AASA configuration; those are external prerequisites, not production changes in this task.
- Content-report `mailto:support@like-art.com` is a placeholder allowed by B2B. Community-specific report/block controls remain B3, not a claim of complete UGC compliance.

## Privacy schema corrections

The manifest declares the requested nine categories, functionality purpose, no tracking, and an unlinked DeviceID. Apple's canonical values are `PhysicalAddress` and `PhotosorVideos`. UserDefaults uses **CA92.1** (the work order's CA9.1 is not a current reason). Cache metadata uses **C617.1**. Keychain is not a required-reason API category; an invented C5B2.1 Keychain entry is not emitted.

Sources: [Apple required-reason API types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [Apple collected data types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype), [GitHub macOS 15 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).

Static checks: `python3 ios-b2/ci/verify_source.py`. The authoritative compiler/signing/package checks run on macOS in CI. Device testing (push reception, biometric hardware, WebKit sign-in and deletion interaction) remains distinct from successful compilation and ASC processing.
