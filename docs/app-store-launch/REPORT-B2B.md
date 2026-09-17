# REPORT-B2B — Like Art iOS 原生壳与 Xcode 26 构建证据

时间：2026-09-17T01:54:34.420475+00:00（UTC）

## 验收结论

**构建交付通过；工单整体尚未通过：ASC 上传与 VALID 验收被 Apple 账户协议阻断。**

- 隔离仓库：`/opt/like-art-ios-b2`；SSH remote：`git@github.com:likeart168/like-art-ios.git`。
- 分支：`b2-native-shell`；本次已推送、已编译的源码 SHA：`658a87ef00d548cd75123432cde712a031578fb7`。
- Actions：[run 35172036883](https://github.com/likeart168/like-art-ios/actions/runs/35172036883)，GitHub conclusion=`success`。
- IPA：[ LikeArt-B2-202609170151 ](https://github.com/likeart168/like-art-ios/actions/runs/35172036883/artifacts/10477211188)，artifact ID `10477211188`，大小 `1475028` 字节；过期 `2026-10-17T01:53:39Z`。
- 原始 stdout：[CI 证据分支](https://github.com/likeart168/like-art-ios/tree/b2-build-evidence/docs/app-store-launch/ci/35172036883)；证据 artifact 同一 run 内保存 30 天。
- Bundle=`com.likeart.app`，显示名=`Like Art`，版本=`1.0.0`，build=`202609170151`。
- 上传步骤按工单配置 `continue-on-error: true`，所以 GitHub 显示绿色不等于上传成功。以下保存 `steps.asc.outcome` 与 Apple 原始错误，**不宣称已在 ASC 出现或 VALID，不宣称 TestFlight 内部组可安装**。

| 工单验收项 | 实际结果 |
|---|---|
| Xcode 26 + unsigned build + archive/sign/export | 通过，见原始 stdout |
| IPA artifact / Payload / executable / LaunchScreen | 通过，CI unzip 与 codesign 检查 |
| Assets.car / iPad 76、152、167 图标 | 通过，actool 非容错执行 |
| 三语权限 / 时间戳版本 / 加密声明 | 通过，见 plutil 输出 |
| 四 Tab / Keychain / push / 注销 / whitelist / UA | 通过静态检查，未冒充真机测试 |
| 实际上传与 ASC 精确 build 查询 | 未通过，Apple 协议 403 |
| ASC processingState=VALID / TestFlight 组 | 无证据，未完成 |

## 实现与范围

SwiftUI 原生商城/世界/消息/我的；原生 LaunchScreen、导航栏与加载/离线页。商城和世界使用 WKWebView，UA 包含 `LikeArtApp/1.0`，只将 `https://like-art.com` 与 `https://www.like-art.com` 的站内主框架导航留在壳内。原生 bridge 限主框架和白名单源；JWT 进 Keychain，Cookie 与 URLSession 同步；API 拒绝重定向。

原生 UITableView 聚合站内通知与按账号落盘的推送历史。通知先请求工单 `/api/auth/notifications`，404 时使用 Android 已实现的 `/api/social/notifications`。账户卡支持 `/api/auth/me` 的 `data.user`、昵称、头像、等级和积分。注销状态独立于积分服务读取；申请前说明30天并确认，之后显示倒计时和撤销入口，中英俄三语。

可选择开启生物识别：`.biometryCurrentSet` 的 Keychain item 保护凭证，下次启动先解锁再加载内容；未凭空实现服务端 refresh endpoint。离线账户、消息与通知历史使用本机 JSON；网页采用系统缓存，失败时可进入原生离线内容页。举报 mailto 是本工单允许的占位，正式社区举报/屏蔽仍属 B3。

实际修改范围仅隔离仓库与本报告。没有进入或修改 `/opt/like-art-app`，没有修改 Android 工程、nginx、主站服务或任何生产业务文件；没有重启服务，没有安装重型构建工具，没有发起真实账号注销/推送发送。构建只在 GitHub macOS runner 完成。本次没有启动浏览器；机器上其他会话现有浏览器未操作。

## 外部阻塞与恢复路径

1. Apple 返回 `FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED`。这是本次真实上传及 API 访问错误，不能通过客户端改码使协议生效。由 Account Holder 在 Apple Developer / ASC 查看并处理待签或到期协议；[Apple 角色权限](https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions)说明只有 Account Holder 可签法律协议。没有代签，也没有反复请求用户确认。
2. 协议处理后，重新运行 `build-b2.yml` 会生成新时间戳 IPA 并自动上传、轮询精确 build 到 VALID；或在有当前 ASC 凭证的环境执行 `BUILD_NUMBER=202609170151 build-b2/venv/bin/python ios-b2/ci/asc.py --query-only` 查询本次版本。上传失败时当前包尚不能凭查询变成 VALID，须先上传。
3. 现有分发 profile 缺少 APNs 和 Associated Domains capability。壳有 device token 注册、通知偏好同步、分享和入站 URL 分流，但真实 APNs / Universal Links 依赖 Hermes 开通能力并更新 profile/AASA；未伪造 entitlement。证书/描述文件导入和签名本身已通过。
4. 真机 WebKit 登录、Face ID、通知到达及注销交互验证未执行；应在解除 ASC 阻塞后的 TestFlight 阶段验收。仅构建成功不代表这些交互已实测。

复用的 secret 名称为 `P12_CERTIFICATE`、`P12_PASSWORD`、`PROVISIONING_PROFILE`、`AUTHKEY_BASE64`、`APPSTORE_KEY_ID`、`APPSTORE_ISSUER_ID`。本机没有 GitHub API token；只读取公共运行 API，并由 CI 将非秘密 stdout 发布到证据分支，未导出私钥/JWT。本轮 `asc-request-metadata.json` 确认实际 secret 的 key ID 为 **`2W7A5K57L2`，并非工单要求的 `RA48U82CSV`**。后者私钥在本机未找到，因此不能宣称已切换最新密钥；需要将仓库 `AUTHKEY_BASE64` 与 `APPSTORE_KEY_ID` 成对更新为 RA48U82CSV 的有效内容（不要只改 ID）。本机无 GitHub token，未读取或改写 secret 值；当前旧 key 发出的请求确实得到 Apple 协议 403，不能据此宣称最新 key 验证通过。

工单提及的 `references/github-actions-native-ios-build.md`、`references/asc-api-*.md` 和本地 `AuthKey_RA48U82CSV.p8` 未在隔离环境可访问位置找到；没有凭空声称读过。已读取总体 B2 工单、A3 隐私标签、B2A Android 原生结构，实际复用现有 CI secrets 与仓库已有签名材料。ASC App ID `6777511498` 来源为上架 `BOARD.md` 的 A1 条目。

隐私枚举按 [Apple 当前定义](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)校正：UserDefaults=`CA92.1`，缓存文件元数据=`C617.1`；Keychain 不属于 required-reason API 类别，未写入无效 `C5B2.1` 声明。九类收集信息均 functionality、tracking=false；DeviceID 按工单设为不关联。规范枚举为 PhysicalAddress 与 PhotosorVideos。

## Git 交付

初始提交按工单使用 `feat(b2b): native shell + xcode26 CI`（`52124cf6aefdf8eae2e5fb9ae1ff00331738875a`），后续向前修复 CI 和源码，最终验收的代码 SHA 为 `658a87ef00d548cd75123432cde712a031578fb7`，均经 SSH 推送到 `b2-native-shell`。本报告的后续 docs commit 不改变该已构建源码；报告内明确区分源码 SHA 与报告提交。

## 真实证据

### summary.txt

```text
Run: https://github.com/likeart168/like-art-ios/actions/runs/35172036883
SHA: 658a87ef00d548cd75123432cde712a031578fb7
Build number: 202609170151
Build status before evidence publication: success
ASC step outcome: failure
ASC HTTP 403: {
"errors" : [ {
"id" : "6CLRQ7ZQAMEQEVO6FKYDAGCIE4",
"status" : "403",
"code" : "FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED",
"title" : "A required agreement is missing or has expired.",
"detail" : "This request requires an in-effect agreement that has not been signed or has expired.",
"links" : {
"see" : "/business"
}
} ]
}
```

### asc-request-metadata.json

```text
{
  "keyId": "2W7A5K57L2",
  "issuerId": "8ad4234e-2fc0-4943-8cde-e8bff3541efb",
  "appId": "6777511498",
  "buildNumber": "202609170151"
}
```

### xcode-version.txt

```text
Xcode 26.3
Build version 17C529
```

### signing-profile.json

```text
{
  "name": "LikeArt App Store",
  "uuid": "fad0d533-ab97-48d8-8a60-944c6f3b91af",
  "expires": "2027-06-06T05:54:14",
  "apns": "NOT_PROVISIONED",
  "associatedDomains": "NOT_PROVISIONED"
}
```

### ipa-sha256.txt

```text
94a8c877915a7a72d9176d27295512e66a541be4d0d564e38319df5ab27792f2  build-b2/export/LikeArt.ipa
```

### executable.txt

```text
build-b2/verify/Payload/LikeArt.app/LikeArt: Mach-O 64-bit executable arm64
```

### codesign-verify.txt

```text
build-b2/verify/Payload/LikeArt.app: valid on disk
build-b2/verify/Payload/LikeArt.app: satisfies its Designated Requirement
```

### ipa-contents.txt

```text
Archive:  build-b2/export/LikeArt.ipa
  Length      Date    Time    Name
---------  ---------- -----   ----
        0  09-17-2026 01:53   Payload/
        0  09-17-2026 01:53   Payload/LikeArt.app/
        0  09-17-2026 01:53   Payload/LikeArt.app/_CodeSignature/
     5000  09-17-2026 01:53   Payload/LikeArt.app/_CodeSignature/CodeResources
        0  09-17-2026 01:53   Payload/LikeArt.app/zh-Hans.lproj/
      255  09-17-2026 01:53   Payload/LikeArt.app/zh-Hans.lproj/InfoPlist.strings
        0  09-17-2026 01:53   Payload/LikeArt.app/en.lproj/
      312  09-17-2026 01:53   Payload/LikeArt.app/en.lproj/InfoPlist.strings
    17759  09-17-2026 01:53   Payload/LikeArt.app/AppIcon60x60@2x.png
   413696  09-17-2026 01:53   Payload/LikeArt.app/LikeArt
        0  09-17-2026 01:53   Payload/LikeArt.app/Base.lproj/
        0  09-17-2026 01:53   Payload/LikeArt.app/Base.lproj/LaunchScreen.storyboardc/
     2745  09-17-2026 01:53   Payload/LikeArt.app/Base.lproj/LaunchScreen.storyboardc/launch-controller-view-launch-view.nib
      932  09-17-2026 01:53   Payload/LikeArt.app/Base.lproj/LaunchScreen.storyboardc/UIViewController-launch-controller.nib
      279  09-17-2026 01:53   Payload/LikeArt.app/Base.lproj/LaunchScreen.storyboardc/Info.plist
  1168728  09-17-2026 01:53   Payload/LikeArt.app/Assets.car
    27215  09-17-2026 01:53   Payload/LikeArt.app/AppIcon76x76@2x~ipad.png
     4231  09-17-2026 01:53   Payload/LikeArt.app/PrivacyInfo.xcprivacy
        0  09-17-2026 01:53   Payload/LikeArt.app/ru.lproj/
      424  09-17-2026 01:53   Payload/LikeArt.app/ru.lproj/InfoPlist.strings
    12064  09-17-2026 01:53   Payload/LikeArt.app/embedded.mobileprovision
     2374  09-17-2026 01:53   Payload/LikeArt.app/Info.plist
        8  09-17-2026 01:53   Payload/LikeArt.app/PkgInfo
        0  09-17-2026 01:53   Symbols/
   804644  09-17-2026 01:53   Symbols/2B340B3E-B8F6-3F41-983D-6321E9E973A8.symbols
---------                     -------
  2460666                     25 files
```

### ipa-info-plist.txt

```text
{
  "BuildMachineOSBuild" => "24G830"
  "CFBundleDevelopmentRegion" => "en"
  "CFBundleDisplayName" => "Like Art"
  "CFBundleExecutable" => "LikeArt"
  "CFBundleIcons" => {
    "CFBundlePrimaryIcon" => {
      "CFBundleIconFiles" => [
        0 => "AppIcon60x60"
      ]
      "CFBundleIconName" => "AppIcon"
    }
  }
  "CFBundleIcons~ipad" => {
    "CFBundlePrimaryIcon" => {
      "CFBundleIconFiles" => [
        0 => "AppIcon60x60"
        1 => "AppIcon76x76"
      ]
      "CFBundleIconName" => "AppIcon"
    }
  }
  "CFBundleIdentifier" => "com.likeart.app"
  "CFBundleInfoDictionaryVersion" => "6.0"
  "CFBundleLocalizations" => [
    0 => "en"
    1 => "zh-Hans"
    2 => "ru"
  ]
  "CFBundleName" => "LikeArt"
  "CFBundlePackageType" => "APPL"
  "CFBundleShortVersionString" => "1.0.0"
  "CFBundleSupportedPlatforms" => [
    0 => "iPhoneOS"
  ]
  "CFBundleVersion" => "202609170151"
  "DTCompiler" => "com.apple.compilers.llvm.clang.1_0"
  "DTPlatformBuild" => "23C57"
  "DTPlatformName" => "iphoneos"
  "DTPlatformVersion" => "26.2"
  "DTSDKBuild" => "23C57"
  "DTSDKName" => "iphoneos26.2"
  "DTXcode" => "2630"
  "DTXcodeBuild" => "17C529"
  "ITSAppUsesNonExemptEncryption" => 0
  "LSRequiresIPhoneOS" => 1
  "MinimumOSVersion" => "16.0"
  "NSAppTransportSecurity" => {
    "NSAllowsArbitraryLoads" => 0
    "NSExceptionDomains" => {
      "like-art.com" => {
        "NSExceptionAllowsInsecureHTTPLoads" => 0
        "NSExceptionMinimumTLSVersion" => "TLSv1.2"
        "NSIncludesSubdomains" => 1
      }
    }
  }
  "NSCameraUsageDescription" => "用于拍摄并上传头像或作品。 / Take photos to upload your avatar or artwork. / Съёмка и загрузка аватара или работ."
  "NSFaceIDUsageDescription" => "使用面容识别验证您的账户。 / Verify your account with Face ID. / Подтверждение аккаунта с помощью Face ID."
  "NSMicrophoneUsageDescription" => "仅在您使用直播时录制声音。 / Record audio when you start a live stream. / Запись звука при запуске прямого эфира."
  "UIApplicationSupportsIndirectInputEvents" => 1
  "UIDeviceFamily" => [
    0 => 1
    1 => 2
  ]
  "UILaunchStoryboardName" => "LaunchScreen"
  "UIRequiredDeviceCapabilities" => [
    0 => "arm64"
  ]
  "UISupportedInterfaceOrientations" => [
    0 => "UIInterfaceOrientationPortrait"
    1 => "UIInterfaceOrientationLandscapeLeft"
    2 => "UIInterfaceOrientationLandscapeRight"
  ]
  "UISupportedInterfaceOrientations~ipad" => [
    0 => "UIInterfaceOrientationPortrait"
    1 => "UIInterfaceOrientationPortraitUpsideDown"
    2 => "UIInterfaceOrientationLandscapeLeft"
    3 => "UIInterfaceOrientationLandscapeRight"
  ]
}
```

### permissions-en.txt

```text
{
  "CFBundleDisplayName" => "Like Art"
  "NSCameraUsageDescription" => "Take photos to upload your avatar or artwork."
  "NSFaceIDUsageDescription" => "Verify your account with Face ID."
  "NSMicrophoneUsageDescription" => "Record audio when you start a live stream."
}
```

### permissions-zh-Hans.txt

```text
{
  "CFBundleDisplayName" => "Like Art"
  "NSCameraUsageDescription" => "用于拍摄并上传头像或作品。"
  "NSFaceIDUsageDescription" => "使用面容识别验证您的账户。"
  "NSMicrophoneUsageDescription" => "仅在您使用直播时录制声音。"
}
```

### permissions-ru.txt

```text
{
  "CFBundleDisplayName" => "Like Art"
  "NSCameraUsageDescription" => "Съёмка и загрузка аватара или работ."
  "NSFaceIDUsageDescription" => "Подтверждение аккаунта с помощью Face ID."
  "NSMicrophoneUsageDescription" => "Запись звука при запуске прямого эфира."
}
```

### privacy-manifest.txt

```text
{
  "NSPrivacyAccessedAPITypes" => [
    0 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryFileTimestamp"
      "NSPrivacyAccessedAPITypeReasons" => [
        0 => "C617.1"
      ]
    }
    1 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryUserDefaults"
      "NSPrivacyAccessedAPITypeReasons" => [
        0 => "CA92.1"
      ]
    }
  ]
  "NSPrivacyCollectedDataTypes" => [
    0 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeEmailAddress"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    1 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypePhoneNumber"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    2 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeName"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    3 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypePhysicalAddress"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    4 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypePurchaseHistory"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    5 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeUserID"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    6 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeDeviceID"
      "NSPrivacyCollectedDataTypeLinked" => 0
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    7 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypePhotosorVideos"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
    8 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeAudioData"
      "NSPrivacyCollectedDataTypeLinked" => 1
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => 0
    }
  ]
  "NSPrivacyTracking" => 0
  "NSPrivacyTrackingDomains" => [
  ]
}
```

### source-assertions.txt

```text
PASS four native tabs: 4
PASS KeychainStore: 2
PASS APNs registration: 1
PASS deletion status: 2
PASS request deletion: 1
PASS cancel deletion: 1
PASS domain whitelist: 1
PASS UA: 4
PASS native table: 9
PASS cookie store: 2
PASS bridge: 5
PASS source Info.plist, three languages, launch screen, privacy manifest and all iPad icon sizes
```

### asc-upload.txt

```text
Running altool at path '/Applications/Xcode_26.3.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources/altool'...

2026-09-17 01:53:46.196 ERROR: [altool.60000216C4C0] Failed to determine the Apple ID from Bundle ID 'com.likeart.app' with platform 'IOS'. A required agreement is missing or has expired. (403) (12)
```

### asc-build-error.json

```text
{
"errors" : [ {
"id" : "6CLRQ7ZQAMEQEVO6FKYDAGCIE4",
"status" : "403",
"code" : "FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED",
"title" : "A required agreement is missing or has expired.",
"detail" : "This request requires an in-effect agreement that has not been signed or has expired.",
"links" : {
"see" : "/business"
}
} ]
}
```

### 静态 rg 原文

```text
ios-b2/Sources/Bridge/JSBridge.swift:11:          if (location.protocol !== 'https:' || !['like-art.com','www.like-art.com'].includes(location.hostname)) return;
ios-b2/Sources/App.swift:26:                    TabView(selection: $session.selectedTab) {
ios-b2/Sources/App.swift:27:                MarketplaceTab().tabItem { Label(tr("商城", "Shop", "Магазин"), systemImage: "bag") }.tag(0)
ios-b2/Sources/App.swift:28:                WorldTab().tabItem { Label(tr("世界", "World", "Мир"), systemImage: "globe") }.tag(1)
ios-b2/Sources/App.swift:29:                MessagesTab().tabItem { Label(tr("消息", "Messages", "Сообщения"), systemImage: "bell") }.tag(2)
ios-b2/Sources/App.swift:30:                ProfileTab().tabItem { Label(tr("我的", "Profile", "Профиль"), systemImage: "person.crop.circle") }.tag(3)
ios-b2/Sources/Auth/AppSession.swift:32:        url.scheme == "https" && ["like-art.com", "www.like-art.com"].contains(url.host?.lowercased() ?? "")
ios-b2/Sources/Auth/AppSession.swift:93:        cookies.filter { $0.domain == "like-art.com" || $0.domain == ".like-art.com" || $0.domain == "www.like-art.com" }.forEach { shared.setCookie($0) }
ios-b2/Sources/Auth/AppSession.swift:99:        request.setValue("LikeArtApp/1.0 iOS", forHTTPHeaderField: "User-Agent")
ios-b2/Sources/Auth/KeychainStore.swift:6:    // Generic passwords use kSecClassGenericPassword + kSecAttrAccount.
ios-b2/Sources/Auth/KeychainStore.swift:8:        kSecClass as String: kSecClassGenericPassword,
ios-b2/Sources/Tabs/MarketplaceTab.swift:59:        configuration.applicationNameForUserAgent = "LikeArtApp/1.0"
ios-b2/Sources/Tabs/MarketplaceTab.swift:71:            if let ua = value as? String { view.customUserAgent = ua.contains("LikeArtApp/1.0") ? ua : ua + " LikeArtApp/1.0" }
ios-b2/Sources/Tabs/ProfileTab.swift:132:            let deletion = try await session.request("/api/auth/deletion-status")
ios-b2/Sources/Tabs/ProfileTab.swift:142:            _ = try await session.request("/api/auth/" + (request ? "request-deletion" : "cancel-deletion"), body: [:])
ios-b2/Sources/Tabs/ProfileTab.swift:144:            let result = try await session.request("/api/auth/deletion-status")
ios-b2/Sources/Push/PushDelegate.swift:44:            _ = try await AppSession.shared.request("/api/auth/push-register", body: ["token": deviceToken, "platform": "ios", "enabled": enabled])
```

### 公共 GitHub API artifact 原文

```json
{
  "total_count": 2,
  "artifacts": [
    {
      "id": 10477730392,
      "node_id": "MDg6QXJ0aWZhY3QxMDQ3NzczMDM5Mg==",
      "name": "LikeArt-B2-evidence-35172036883",
      "size_in_bytes": 26085,
      "url": "https://api.github.com/repos/likeart168/like-art-ios/actions/artifacts/10477730392",
      "archive_download_url": "https://api.github.com/repos/likeart168/like-art-ios/actions/artifacts/10477730392/zip",
      "expired": false,
      "digest": "sha256:4bb6c41526f53ba1d7b12c6f78776f48b6c86b76264aaddbfa08bf113fc1ad87",
      "created_at": "2026-09-17T01:53:47Z",
      "updated_at": "2026-09-17T01:53:47Z",
      "expires_at": "2026-10-17T01:53:47Z",
      "workflow_run": {
        "id": 35172036883,
        "repository_id": 1261528906,
        "head_repository_id": 1261528906,
        "head_branch": "b2-native-shell",
        "head_sha": "658a87ef00d548cd75123432cde712a031578fb7"
      }
    },
    {
      "id": 10477211188,
      "node_id": "MDg6QXJ0aWZhY3QxMDQ3NzIxMTE4OA==",
      "name": "LikeArt-B2-202609170151",
      "size_in_bytes": 1475028,
      "url": "https://api.github.com/repos/likeart168/like-art-ios/actions/artifacts/10477211188",
      "archive_download_url": "https://api.github.com/repos/likeart168/like-art-ios/actions/artifacts/10477211188/zip",
      "expired": false,
      "digest": "sha256:c07f20ef11ce7c133891dc6134ed7aea9bfb2d2edafe89ff53344b79c3621eb6",
      "created_at": "2026-09-17T01:53:40Z",
      "updated_at": "2026-09-17T01:53:40Z",
      "expires_at": "2026-10-17T01:53:39Z",
      "workflow_run": {
        "id": 35172036883,
        "repository_id": 1261528906,
        "head_repository_id": 1261528906,
        "head_branch": "b2-native-shell",
        "head_sha": "658a87ef00d548cd75123432cde712a031578fb7"
      }
    }
  ]
}
```

### 真实 job steps（GitHub API）

```json
[
  {
    "id": 105045888584,
    "status": "completed",
    "conclusion": "success",
    "steps": [
      {
        "name": "Set up job",
        "status": "completed",
        "conclusion": "success",
        "number": 1,
        "started_at": "2026-09-17T01:51:25Z",
        "completed_at": "2026-09-17T01:51:26Z"
      },
      {
        "name": "Run actions/checkout@v4",
        "status": "completed",
        "conclusion": "success",
        "number": 2,
        "started_at": "2026-09-17T01:51:26Z",
        "completed_at": "2026-09-17T01:51:28Z"
      },
      {
        "name": "Detect and select Xcode 26",
        "status": "completed",
        "conclusion": "success",
        "number": 3,
        "started_at": "2026-09-17T01:51:28Z",
        "completed_at": "2026-09-17T01:51:32Z"
      },
      {
        "name": "Install build tools",
        "status": "completed",
        "conclusion": "success",
        "number": 4,
        "started_at": "2026-09-17T01:51:32Z",
        "completed_at": "2026-09-17T01:51:41Z"
      },
      {
        "name": "Verify source and generate project",
        "status": "completed",
        "conclusion": "success",
        "number": 5,
        "started_at": "2026-09-17T01:51:41Z",
        "completed_at": "2026-09-17T01:51:41Z"
      },
      {
        "name": "Compile asset catalog",
        "status": "completed",
        "conclusion": "success",
        "number": 6,
        "started_at": "2026-09-17T01:51:41Z",
        "completed_at": "2026-09-17T01:52:39Z"
      },
      {
        "name": "Build without signing",
        "status": "completed",
        "conclusion": "success",
        "number": 7,
        "started_at": "2026-09-17T01:52:39Z",
        "completed_at": "2026-09-17T01:53:11Z"
      },
      {
        "name": "Import distribution certificate and profile",
        "status": "completed",
        "conclusion": "success",
        "number": 8,
        "started_at": "2026-09-17T01:53:11Z",
        "completed_at": "2026-09-17T01:53:13Z"
      },
      {
        "name": "Archive and codesign",
        "status": "completed",
        "conclusion": "success",
        "number": 9,
        "started_at": "2026-09-17T01:53:13Z",
        "completed_at": "2026-09-17T01:53:35Z"
      },
      {
        "name": "Export App Store IPA",
        "status": "completed",
        "conclusion": "success",
        "number": 10,
        "started_at": "2026-09-17T01:53:35Z",
        "completed_at": "2026-09-17T01:53:38Z"
      },
      {
        "name": "Preserve IPA artifact",
        "status": "completed",
        "conclusion": "success",
        "number": 11,
        "started_at": "2026-09-17T01:53:38Z",
        "completed_at": "2026-09-17T01:53:40Z"
      },
      {
        "name": "Upload with ASC API key and verify VALID",
        "status": "completed",
        "conclusion": "success",
        "number": 12,
        "started_at": "2026-09-17T01:53:40Z",
        "completed_at": "2026-09-17T01:53:46Z"
      },
      {
        "name": "Build evidence summary",
        "status": "completed",
        "conclusion": "success",
        "number": 13,
        "started_at": "2026-09-17T01:53:46Z",
        "completed_at": "2026-09-17T01:53:46Z"
      },
      {
        "name": "Preserve evidence artifact",
        "status": "completed",
        "conclusion": "success",
        "number": 14,
        "started_at": "2026-09-17T01:53:46Z",
        "completed_at": "2026-09-17T01:53:47Z"
      },
      {
        "name": "Publish stdout evidence for public verification",
        "status": "completed",
        "conclusion": "success",
        "number": 15,
        "started_at": "2026-09-17T01:53:47Z",
        "completed_at": "2026-09-17T01:53:52Z"
      },
      {
        "name": "Clean temporary signing resources",
        "status": "completed",
        "conclusion": "success",
        "number": 16,
        "started_at": "2026-09-17T01:53:52Z",
        "completed_at": "2026-09-17T01:53:52Z"
      },
      {
        "name": "Post Run actions/checkout@v4",
        "status": "completed",
        "conclusion": "success",
        "number": 32,
        "started_at": "2026-09-17T01:53:52Z",
        "completed_at": "2026-09-17T01:53:52Z"
      },
      {
        "name": "Complete job",
        "status": "completed",
        "conclusion": "success",
        "number": 33,
        "started_at": "2026-09-17T01:53:52Z",
        "completed_at": "2026-09-17T01:53:54Z"
      }
    ]
  }
]
```

## CI 编译、图标与导出完整 stdout

以下为 runner 产出的原文，保留绝对 runner 路径与时间戳。

<details><summary>actool.txt</summary>

### actool.txt

```text
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.actool.compilation-results</key>
	<dict>
		<key>output-files</key>
		<array>
			<string>/Users/runner/work/like-art-ios/like-art-ios/build-b2/asset-info.plist</string>
			<string>/Users/runner/work/like-art-ios/like-art-ios/build-b2/assets/AppIcon60x60@2x.png</string>
			<string>/Users/runner/work/like-art-ios/like-art-ios/build-b2/assets/AppIcon76x76@2x~ipad.png</string>
			<string>/Users/runner/work/like-art-ios/like-art-ios/build-b2/assets/Assets.car</string>
		</array>
	</dict>
</dict>
</plist>
```

</details>

<details><summary>unsigned-build.txt</summary>

### unsigned-build.txt

```text
Command line invocation:
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/xcodebuild -project ios-b2/LikeArt.xcodeproj -scheme LikeArt -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build-b2/DerivedData build CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION=202609170151

Build settings from command line:
    CODE_SIGNING_ALLOWED = NO
    CURRENT_PROJECT_VERSION = 202609170151
    SDKROOT = iphoneos26.2

ComputePackagePrebuildTargetDependencyGraph

Prepare packages

CreateBuildRequest

SendProjectDescription

CreateBuildOperation

ComputeTargetDependencyGraph
note: Building targets in dependency order
note: Target dependency graph (1 target)
    Target 'LikeArt' in project 'LikeArt' (no dependencies)

GatherProvisioningInputs

CreateBuildDescription

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool --print-asset-tag-combinations --output-format xml1 /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --version --output-format xml1

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -v -E -dM -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -x c -c /dev/null

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool --version --output-format xml1

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc --version

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld -version_details

Build description signature: 5ed1bc9e97b111c52c2eb117c7f03da3
Build description path: /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/XCBuildData/5ed1bc9e97b111c52c2eb117c7f03da3.xcbuilddata
CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products

CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex

ClangStatCache /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -o /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache

CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt-018e02f47962fc73e3fc6ce74ef9efff-VFS-iphoneos/all-product-headers.yaml
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt-018e02f47962fc73e3fc6ce74ef9efff-VFS-iphoneos/all-product-headers.yaml

CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.hmap

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap

WriteAuxiliaryFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-non-framework-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-non-framework-target-headers.hmap

MkDir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app

MkDir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned

MkDir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned

GenerateAssetSymbols /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets --compile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies --output-partial-info-plist /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --platform iphoneos --bundle-identifier com.likeart.app --generate-swift-asset-symbol-extensions NO --generate-swift-asset-symbols /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift --generate-objc-asset-symbols /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.h --generate-asset-symbol-index /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/* com.apple.actool.compilation-results */
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.h
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift


CpResource /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/PrivacyInfo.xcprivacy /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/PrivacyInfo.xcprivacy (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/PrivacyInfo.xcprivacy /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app

CopyStringsFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/zh-Hans.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/zh-Hans.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CopyStringsFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/ru.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/ru.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CopyStringsFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/en.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/en.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CompileStoryboard /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Base.lproj/LaunchScreen.storyboard (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --errors --warnings --notices --module LikeArt --output-partial-info-plist /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen-SBPartialInfo.plist --auto-activate-custom-fonts --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --output-format human-readable-text /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Base.lproj/LaunchScreen.storyboard --compilation-directory /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj

CompileAssetCatalogVariant thinned /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets --compile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_thinned --output-partial-info-plist /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --platform iphoneos
/* com.apple.actool.document.notices */
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets:./AppIcon.appiconset/[][ipad][76x76][][][1x][][][][]: notice: 76x76@1x app icons only apply to iPad apps targeting releases of iOS prior to 10.0.
/* com.apple.actool.compilation-results */
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/AppIcon60x60@2x.png
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/AppIcon76x76@2x~ipad.png
/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/Assets.car


LinkStoryboards (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --errors --warnings --notices --module LikeArt --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --output-format human-readable-text --link /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen.storyboardc

SwiftDriver LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-SwiftDriver -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -F /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftDriver\ Compilation LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-Swift-Compilation -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -F /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/DeveloperToolsSupport-AUXYQPOFUTPJM7Y3D55801FL8.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_SwiftConcurrencyShims-6TDY9ZQ510BTJEMDXC1GFDFJ1.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ptrauth-8VNUOHLEZSTXVKKJX35H0QV7G.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stddef-A56SY8UA5GCOFVFFJS506WOMR.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdarg-31KWGXLDFEF23GIBIMKBIG94F.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ptrcheck-3WB7E91QU4QNLNCIQOVNMO2PV.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftShims-AQDHJNHS402U4ZCPH38QE7NIP.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdbool-BX8CLDD3QGNB3BK78FOSK48TU.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_float-7L6MH4JWVTXJAJOI73196R766.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_AvailabilityInternal-E8U5QVW2LCXJ6TVYX31MMS2C9.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation1-EFPOMBL2O64WQTLUI6DNRQ4YR.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation2-BP1UHYPBNJQKPYFYKPEQGG8H3.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_limits-EY9UBHKKJVV4W9P87X9JUB8A5.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdint-88BVF7F5WWD7YC96OV0B9WZWY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_tgmath-2EM07P7AID2QDTOMNZK95PLID.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/sys_types-DLF9LEZAR6IKWEC3P304UFXV6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation3-5VFSR33LDVUCOSD3SZCO00UYO.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdatomic-CU8IIQK07IGWJ26B4M20M3EB4.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_intrinsics-9TXX2L5N7P4WPMQ7EJ94IWT80.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_inttypes-95QYEXUX88L1OGMI5ULNAE2B6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Darwin-29UGA7KLXT11B9PJCCE70KBH9.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/simd-48UU7L6PCEKPQU228NA6K1THF.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/MachO-7TIO32X42BMT7HFE9FON7883B.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ObjectiveC-31PF2K3KVAF6FX66U1E32QX29.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os_object-2G7BFR55JHRTJXDPH3HUIAQFR.pcm

LinkAssetCatalog /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-linkAssetCatalog --thinned /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned --thinned-dependencies /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_thinned --thinned-info-plist-content /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned --unthinned /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned --unthinned-dependencies /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_unthinned --unthinned-info-plist-content /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_unthinned --output /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app --plist-output /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist
note: Emplaced /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/AppIcon60x60@2x.png (in target 'LikeArt' from project 'LikeArt')
note: Emplaced /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Assets.car (in target 'LikeArt' from project 'LikeArt')
note: Emplaced /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/AppIcon76x76@2x~ipad.png (in target 'LikeArt' from project 'LikeArt')

ProcessInfoPlistFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Info.plist /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Info.plist (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-infoPlistUtility /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Info.plist -producttype com.apple.product-type.application -genpkginfo /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/PkgInfo -expandbuildsettings -format binary -platform iphoneos -additionalcontentfile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen-SBPartialInfo.plist -additionalcontentfile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist -requiredArchitecture arm64 -o /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Info.plist

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os_workgroup-BBUW73CI7UW1V1RL1EN5LKRVM.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Dispatch-706G4HJ4CP4J67NG9ZLGC3LFZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Spatial-5MWXN7R87K8B7FGEAK041JNA8.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreFoundation-C05WS0HMFRPDVCAUW1DNXAKRD.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/XPC-3JI70U8UEGLIJ2XUXWYSXRFO8.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/dnssd-6CVFGCYRBVDR0X9V2O7X8V9MG.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os-2KO1ZETS8BXYW1VTK7UMWDDRG.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Security-F4910HA8BCNQ6MJQQTPPM4B7R.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CFNetwork-DINVXK1UEKWZF28YZRTXLROOB.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreGraphics-8QPKDWY930AE7E8004C1YC73J.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Foundation-9VMROHCG5ZW4BXQ10ZB1MYDT6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreText-AWQ5J8SR8PQFMD2HD58WZ71HX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ImageIO-6LUCBCDDYRTTRT2U7LT671CBL.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/IOSurface-1K4AEHG02UTAS3ZK1AY93KPOX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreTransferable-CJTF6S9J73OEQLGC02075NYZO.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/FileProvider-5M42XER0LCHBT4TK5R7TF1XH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Symbols-2VH96WY8L61JUZXSHPF7LMFT2.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/DataDetection-73CJPNMG52TIQO6JV7J88XMBQ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Network-N0RJHKPY77FJBQQIPP4AT8IC.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UniformTypeIdentifiers-ELTDZGIWV7EDICUE6ONVXL50V.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Accessibility-1YUIZVRVYNMU0E6Q6HO18S4UF.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UserNotifications-DWPI0ZI388E2JBEN41HWC308Y.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/OpenGLES-6DST28UXCJPGPPNQLPS5KBMGE.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/LocalAuthentication-6124RJ1FGR08CTSTZGS1L1IC.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Metal-ATQC5A6J3SPA5FMJEI4AEHDYL.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreData-4JEQIUMC8J1YYAWIV35996441.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UIUtilities-EIQO1GVL0BF25WSFD2OSHW7EV.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/OSLog-EE9R08WDG19MSDYSFRN17NSPV.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreVideo-84E0CIL31NM97H2Q0RGUMKOJL.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreImage-7O2K76RC1GBV13RYD88P5K6SZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/QuartzCore-95T9S5WHAHH8KYT6Z48PQYXR1.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftUICore-BR29JLVKKHU7T0M2BWKPOOAG9.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UIKit-6M59Q5GIR7E50R3LPPH7H2HER.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/WebKit-2BYS7MQF1QEVRIZZZXPVBZAGT.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftUI-1152E5JXLJ3HA4Y2Y1XCSOI8C.pcm

SwiftCompile normal arm64 Compiling\ App.swift,\ AppSession.swift,\ JSBridge.swift,\ KeychainStore.swift,\ MarketplaceTab.swift,\ MessagesTab.swift,\ ProfileTab.swift,\ PushDelegate.swift,\ WorldTab.swift,\ GeneratedAssetSymbols.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/App.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Auth/AppSession.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Bridge/JSBridge.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Auth/KeychainStore.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/MarketplaceTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/MessagesTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/ProfileTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Push/PushDelegate.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/WorldTab.swift /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreFoundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Symbols.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreTransferable.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Accessibility.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/ObjectiveC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/DeveloperToolsSupport.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Combine.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/UIKit.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_Concurrency.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/LocalAuthentication.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation2.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_StringProcessing.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Darwin.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Network.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation3.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation1.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Metal.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/UniformTypeIdentifiers.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Foundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_WebKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Observation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Spatial.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreData.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/simd.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Swift.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/WebKit.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_Builtin_float.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/FileProvider.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/System.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/os.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Dispatch.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreVideo.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/XPC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/OSLog.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/QuartzCore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/DataDetection.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreImage.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreGraphics.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Distributed.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreText.swiftmodule/arm64e-apple-ios.swiftmodule /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftUICore-BR29JLVKKHU7T0M2BWKPOOAG9.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation1-EFPOMBL2O64WQTLUI6DNRQ4YR.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_float-7L6MH4JWVTXJAJOI73196R766.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_SwiftConcurrencyShims-6TDY9ZQ510BTJEMDXC1GFDFJ1.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftUI-1152E5JXLJ3HA4Y2Y1XCSOI8C.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreData-4JEQIUMC8J1YYAWIV35996441.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdbool-BX8CLDD3QGNB3BK78FOSK48TU.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stddef-A56SY8UA5GCOFVFFJS506WOMR.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_limits-EY9UBHKKJVV4W9P87X9JUB8A5.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_inttypes-95QYEXUX88L1OGMI5ULNAE2B6.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Foundation-9VMROHCG5ZW4BXQ10ZB1MYDT6.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Darwin-29UGA7KLXT11B9PJCCE70KBH9.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/XPC-3JI70U8UEGLIJ2XUXWYSXRFO8.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Security-F4910HA8BCNQ6MJQQTPPM4B7R.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdarg-31KWGXLDFEF23GIBIMKBIG94F.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_AvailabilityInternal-E8U5QVW2LCXJ6TVYX31MMS2C9.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Accessibility-1YUIZVRVYNMU0E6Q6HO18S4UF.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/LocalAuthentication-6124RJ1FGR08CTSTZGS1L1IC.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreGraphics-8QPKDWY930AE7E8004C1YC73J.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ImageIO-6LUCBCDDYRTTRT2U7LT671CBL.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Network-N0RJHKPY77FJBQQIPP4AT8IC.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/DataDetection-73CJPNMG52TIQO6JV7J88XMBQ.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreFoundation-C05WS0HMFRPDVCAUW1DNXAKRD.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UIUtilities-EIQO1GVL0BF25WSFD2OSHW7EV.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreTransferable-CJTF6S9J73OEQLGC02075NYZO.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation2-BP1UHYPBNJQKPYFYKPEQGG8H3.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/WebKit-2BYS7MQF1QEVRIZZZXPVBZAGT.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UserNotifications-DWPI0ZI388E2JBEN41HWC308Y.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Symbols-2VH96WY8L61JUZXSHPF7LMFT2.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os_object-2G7BFR55JHRTJXDPH3HUIAQFR.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os_workgroup-BBUW73CI7UW1V1RL1EN5LKRVM.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/MachO-7TIO32X42BMT7HFE9FON7883B.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/os-2KO1ZETS8BXYW1VTK7UMWDDRG.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UniformTypeIdentifiers-ELTDZGIWV7EDICUE6ONVXL50V.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Dispatch-706G4HJ4CP4J67NG9ZLGC3LFZ.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ptrcheck-3WB7E91QU4QNLNCIQOVNMO2PV.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/FileProvider-5M42XER0LCHBT4TK5R7TF1XH.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/QuartzCore-95T9S5WHAHH8KYT6Z48PQYXR1.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Spatial-5MWXN7R87K8B7FGEAK041JNA8.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ObjectiveC-31PF2K3KVAF6FX66U1E32QX29.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/dnssd-6CVFGCYRBVDR0X9V2O7X8V9MG.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/simd-48UU7L6PCEKPQU228NA6K1THF.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/ptrauth-8VNUOHLEZSTXVKKJX35H0QV7G.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/sys_types-DLF9LEZAR6IKWEC3P304UFXV6.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_intrinsics-9TXX2L5N7P4WPMQ7EJ94IWT80.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/SwiftShims-AQDHJNHS402U4ZCPH38QE7NIP.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/IOSurface-1K4AEHG02UTAS3ZK1AY93KPOX.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_DarwinFoundation3-5VFSR33LDVUCOSD3SZCO00UYO.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/OSLog-EE9R08WDG19MSDYSFRN17NSPV.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreText-AWQ5J8SR8PQFMD2HD58WZ71HX.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CFNetwork-DINVXK1UEKWZF28YZRTXLROOB.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdatomic-CU8IIQK07IGWJ26B4M20M3EB4.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/UIKit-6M59Q5GIR7E50R3LPPH7H2HER.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreImage-7O2K76RC1GBV13RYD88P5K6SZ.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_tgmath-2EM07P7AID2QDTOMNZK95PLID.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/OpenGLES-6DST28UXCJPGPPNQLPS5KBMGE.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/DeveloperToolsSupport-AUXYQPOFUTPJM7Y3D55801FL8.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/_Builtin_stdint-88BVF7F5WWD7YC96OV0B9WZWY.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/CoreVideo-84E0CIL31NM97H2Q0RGUMKOJL.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Metal-ATQC5A6J3SPA5FMJEI4AEHDYL.pcm /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-dependencies-1.json (in target 'LikeArt' from project 'LikeArt')

CompileSwift normal arm64 (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    

SwiftDriverJobDiscovery normal arm64 Compiling App.swift, AppSession.swift, JSBridge.swift, KeychainStore.swift, MarketplaceTab.swift, MessagesTab.swift, ProfileTab.swift, PushDelegate.swift, WorldTab.swift, GeneratedAssetSymbols.swift (in target 'LikeArt' from project 'LikeArt')

SwiftDriver\ Compilation\ Requirements LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-Swift-Compilation-Requirements -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -F /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftMergeGeneratedHeaders /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/LikeArt-Swift.h /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-swiftHeaderTool -arch arm64 /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -o /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/LikeArt-Swift.h

Copy /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftdoc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftdoc (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftdoc /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftdoc

Copy /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftmodule /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftmodule

Copy /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.abi.json /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.abi.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.abi.json /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.abi.json

Copy /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/Project/arm64-apple-ios.swiftsourceinfo /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftsourceinfo (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftsourceinfo /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.swiftmodule/Project/arm64-apple-ios.swiftsourceinfo

Ld /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt normal (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -Xlinker -reproducible -target arm64-apple-ios16.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -Os -L/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos -L/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -F/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos -F/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos -filelist /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList -Xlinker -rpath -Xlinker /usr/lib/swift -Xlinker -rpath -Xlinker @executable_path/Frameworks -dead_strip -Xlinker -object_path_lto -Xlinker /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_lto.o -Xlinker -dependency_info -Xlinker /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_dependency_info.dat -fobjc-link-runtime -L/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos -L/usr/lib/swift -Xlinker -add_ast_path -Xlinker /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule @/Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-linker-args.resp -o /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt

CopySwiftLibs /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt --scan-folder /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Frameworks --scan-folder /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/PlugIns --scan-folder /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/SystemExtensions --scan-folder /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Extensions --platform iphoneos --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.USh6n7/Metal.xctoolchain --toolchain /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

ExtractAppIntentsMetadata (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor --toolchain-dir /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.USh6n7/Metal.xctoolchain --module-name LikeArt --sdk-root /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk --xcode-version 17C529 --platform-family iOS --deployment-target 16.0 --bundle-identifier com.likeart.app --output /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app --target-triple arm64-apple-ios16.0 --binary-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt --dependency-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_dependency_info.dat --stringsdata-file /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/ExtractedAppShortcutsMetadata.stringsdata --source-file-list /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList --metadata-file-list /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList --static-metadata-file-list /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList --swift-const-vals-list /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList --compile-time-extraction --deployment-aware-processing --validate-assistant-intents --no-app-shortcuts-localization
2026-09-17 01:53:11.054 appintentsmetadataprocessor[6525:22407] Starting appintentsmetadataprocessor export
2026-09-17 01:53:11.075 appintentsmetadataprocessor[6525:22407] warning: Metadata extraction skipped. No AppIntents.framework dependency found.

GenerateDSYMFile /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app.dSYM /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/dsymutil /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/LikeArt -o /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app.dSYM

AppIntentsSSUTraining (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor --infoplist-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Info.plist --temp-dir-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/ssu --bundle-id com.likeart.app --product-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app --extracted-metadata-path /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app/Metadata.appintents --metadata-file-list /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Intermediates.noindex/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList --archive-ssu-assets
2026-09-17 01:53:11.155 appintentsnltrainingprocessor[6538:22437] Parsing options for appintentsnltrainingprocessor
2026-09-17 01:53:11.157 appintentsnltrainingprocessor[6538:22437] No AppShortcuts found - Skipping.

RegisterExecutionPolicyException /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-RegisterExecutionPolicyException /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app

Validate /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-validationUtility /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app -shallow-bundle -infoplist-subpath Info.plist

Touch /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /usr/bin/touch -c /Users/runner/work/like-art-ios/like-art-ios/build-b2/DerivedData/Build/Products/Release-iphoneos/LikeArt.app

** BUILD SUCCEEDED **
```

</details>

<details><summary>archive.txt</summary>

### archive.txt

```text
Command line invocation:
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/xcodebuild -project ios-b2/LikeArt.xcodeproj -scheme LikeArt -configuration Release -sdk iphoneos -destination generic/platform=iOS -archivePath build-b2/LikeArt.xcarchive archive CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Apple Distribution" DEVELOPMENT_TEAM=2JZCL349AG PROVISIONING_PROFILE_SPECIFIER=fad0d533-ab97-48d8-8a60-944c6f3b91af CODE_SIGN_ENTITLEMENTS=/Users/runner/work/like-art-ios/like-art-ios/build-b2/LikeArt.entitlements CURRENT_PROJECT_VERSION=202609170151

Build settings from command line:
    CODE_SIGN_ENTITLEMENTS = /Users/runner/work/like-art-ios/like-art-ios/build-b2/LikeArt.entitlements
    CODE_SIGN_IDENTITY = Apple Distribution
    CODE_SIGN_STYLE = Manual
    CURRENT_PROJECT_VERSION = 202609170151
    DEVELOPMENT_TEAM = 2JZCL349AG
    PROVISIONING_PROFILE_SPECIFIER = fad0d533-ab97-48d8-8a60-944c6f3b91af
    SDKROOT = iphoneos26.2

note: Using codesigning identity override: Apple Distribution
ComputePackagePrebuildTargetDependencyGraph

Prepare packages

CreateBuildRequest

SendProjectDescription

CreateBuildOperation

ComputeTargetDependencyGraph
note: Building targets in dependency order
note: Target dependency graph (1 target)
    Target 'LikeArt' in project 'LikeArt' (no dependencies)

GatherProvisioningInputs

CreateBuildDescription

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool --print-asset-tag-combinations --output-format xml1 /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --version --output-format xml1

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -v -E -dM -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -x c -c /dev/null

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool --version --output-format xml1

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc --version

ExecuteExternalTool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld -version_details

Build description signature: 08a79e366f0a03ff46e4e6fba3940897
Build description path: /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/XCBuildData/08a79e366f0a03ff46e4e6fba3940897.xcbuilddata
CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath

ClangStatCache /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk /Users/runner/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -o /Users/runner/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt-018e02f47962fc73e3fc6ce74ef9efff-VFS-iphoneos/all-product-headers.yaml
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt-018e02f47962fc73e3fc6ce74ef9efff-VFS-iphoneos/all-product-headers.yaml

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/SwiftExplicitPrecompiledModules
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/SwiftExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/ExplicitPrecompiledModules
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/ExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/EagerLinkingTBDs/Release-iphoneos
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/EagerLinkingTBDs/Release-iphoneos

CreateBuildDirectory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2/LikeArt.xcodeproj
    builtin-create-build-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-non-framework-target-headers.hmap (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-non-framework-target-headers.hmap

WriteAuxiliaryFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/Entitlements.plist (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    write-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/Entitlements.plist

SymLink /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.app ../../InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/ln -sfh ../../InstallationBuildProductsLocation/Applications/LikeArt.app /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.app

MkDir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

ProcessProductPackaging /Users/runner/work/like-art-ios/like-art-ios/build-b2/LikeArt.entitlements /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    
    Entitlements:
    
    {
    "application-identifier" = "2JZCL349AG.com.likeart.app";
    "beta-reports-active" = 1;
    "com.apple.developer.team-identifier" = 2JZCL349AG;
    "get-task-allow" = 0;
}
    
    builtin-productPackagingUtility /Users/runner/work/like-art-ios/like-art-ios/build-b2/LikeArt.entitlements -entitlements -format xml -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent

ProcessProductPackaging /Users/runner/Library/MobileDevice/Provisioning\ Profiles/fad0d533-ab97-48d8-8a60-944c6f3b91af.mobileprovision /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/embedded.mobileprovision (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-productPackagingUtility /Users/runner/Library/MobileDevice/Provisioning\ Profiles/fad0d533-ab97-48d8-8a60-944c6f3b91af.mobileprovision -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/embedded.mobileprovision

ProcessProductPackagingDER /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent.der (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /usr/bin/derq query -f xml -i /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent.der --raw

MkDir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned

MkDir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/mkdir -p /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned

GenerateAssetSymbols /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets --compile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies --output-partial-info-plist /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --platform iphoneos --bundle-identifier com.likeart.app --generate-swift-asset-symbol-extensions NO --generate-swift-asset-symbols /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift --generate-objc-asset-symbols /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.h --generate-asset-symbol-index /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/* com.apple.actool.compilation-results */
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.h
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift


CpResource /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/PrivacyInfo.xcprivacy /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/PrivacyInfo.xcprivacy (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/PrivacyInfo.xcprivacy /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

CopyStringsFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/zh-Hans.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/zh-Hans.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/zh-Hans.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CopyStringsFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/ru.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/ru.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/ru.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CopyStringsFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/en.lproj/InfoPlist.strings /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copyStrings --validate --outputencoding binary --outfilename InfoPlist.strings --outdir /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/en.lproj -- /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/en.lproj/InfoPlist.strings:1:1: note: detected encoding of input file as Unicode (UTF-8) (in target 'LikeArt' from project 'LikeArt')

CompileStoryboard /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Base.lproj/LaunchScreen.storyboard (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --errors --warnings --notices --module LikeArt --output-partial-info-plist /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen-SBPartialInfo.plist --auto-activate-custom-fonts --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --output-format human-readable-text /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Base.lproj/LaunchScreen.storyboard --compilation-directory /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj

CompileAssetCatalogVariant thinned /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/actool /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets --compile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_thinned --output-partial-info-plist /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --platform iphoneos
/* com.apple.actool.document.notices */
/Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets:./AppIcon.appiconset/[][ipad][76x76][][][1x][][][][]: notice: 76x76@1x app icons only apply to iPad apps targeting releases of iOS prior to 10.0.
/* com.apple.actool.compilation-results */
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/AppIcon60x60@2x.png
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/AppIcon76x76@2x~ipad.png
/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned/Assets.car


LinkStoryboards (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/usr/bin/ibtool --errors --warnings --notices --module LikeArt --target-device iphone --target-device ipad --minimum-deployment-target 16.0 --output-format human-readable-text --link /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen.storyboardc

SwiftDriver LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-SwiftDriver -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -F /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/include -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftDriver\ Compilation LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-Swift-Compilation -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -F /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/include -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftShims-1MABNWY2W4HF8PYUD6BPT5TAZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdbool-1LLN5I6AFV2FB1ULCXWW6LIU2.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/DeveloperToolsSupport-D568ZZV5GGF0HFGCU6IJBWL0Y.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ptrauth-6TNDJ1I13XOQELTZ0D2F0AORS.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ptrcheck-1HIKBYLY7BD7BK2PKP5FSL4FM.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stddef-MBBM0180A1YES5J798B0CHC2.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdarg-57H4QFD9B934F5ZYBYG28698J.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_SwiftConcurrencyShims-5M2E6NYWF7WHRNPE9M3NRLZH0.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_float-AYIK33CJ5ACSJYYNVVDLG5TDC.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_AvailabilityInternal-EHRSA4T93JD5QEUGJ4PTAI3M8.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation1-6ZU0UEPX0G9XJUA5ALZRSZOMT.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_limits-E4B238HZGLY1ZAM9HGAUL5BZC.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation2-9JX2D1281Q0XH8CM3LQ2737PD.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdint-6RPBNTXHWM32RJJKSQ33YGSGY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/sys_types-BPLASASPFW8M9Z4BFTNEUTF7V.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_tgmath-AHAP65LMXJS8ZTBGQ5B39QIK6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation3-4BB489964JBZUNHUM48O90AUK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdatomic-CSOPI357L8ONDB1EBUOD7GGZ6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_intrinsics-2WQ78P0CTVC5LQGLTTCIOQ55W.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_inttypes-3OBPYU86LQVMHE4ALFULA429D.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Darwin-19GMPWSXGL9FC52TDPWRSZ9XN.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/simd-BE08MGU4C70SIZN7WRMT4C662.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ObjectiveC-DST8KR6FLTFFLUW0FTUVWTU99.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/MachO-91TI5A8RJI2RE5HWSKR7FYB9K.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os_object-8RQH58KNMHJU51VUJA5Q8688F.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os_workgroup-392XDKSQMB85FF3G5JXC01S1T.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Dispatch-DUVR2OTVRYC037CNRE6II4GNY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/XPC-8TO1KJNLLR6LO820J48QIMJU4.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreFoundation-9DR2Q8H3U186RZ580BJVU3O70.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/dnssd-ENOAOW24RM779HUEVVAVECC3X.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Spatial-AN6YBETRUBDVKVFEUPPTKNAQX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os-8RBHLU86HK0KJ848VCDJH62IH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CFNetwork-4UOIK5028KAN7Q8Y076ZUDYMB.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreGraphics-17XONOP6U10SWL9IVBVYY65CS.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Security-5XUAQK7VBDU1X4SKPR8PJS6QH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreText-AHV2MNP8KH5HHMCJ6DHNL3VTF.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ImageIO-7OPD7WHSN743XN01WY7DG9EU3.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Foundation-9PFEAT7JAOD51MPKB0F9Z5KCF.pcm

LinkAssetCatalog /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Resources/Assets.xcassets (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-linkAssetCatalog --thinned /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/thinned --thinned-dependencies /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_thinned --thinned-info-plist-content /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_thinned --unthinned /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_output/unthinned --unthinned-dependencies /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_dependencies_unthinned --unthinned-info-plist-content /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist_unthinned --output /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app --plist-output /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist
note: Emplaced /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/AppIcon76x76@2x~ipad.png (in target 'LikeArt' from project 'LikeArt')
note: Emplaced /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/AppIcon60x60@2x.png (in target 'LikeArt' from project 'LikeArt')
note: Emplaced /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Assets.car (in target 'LikeArt' from project 'LikeArt')

ProcessInfoPlistFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Info.plist /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Info.plist (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-infoPlistUtility /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Info.plist -producttype com.apple.product-type.application -genpkginfo /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/PkgInfo -expandbuildsettings -format binary -platform iphoneos -additionalcontentfile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Base.lproj/LaunchScreen-SBPartialInfo.plist -additionalcontentfile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/assetcatalog_generated_info.plist -requiredArchitecture arm64 -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Info.plist

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/LocalAuthentication-B96FLNGGYONCUTFRZKAGUIQBN.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/DataDetection-4GEOMCRCQ37HCQS5BGMAE1UVW.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UniformTypeIdentifiers-DDGLRV6HLNJZ1RCIBZ0HQQ34P.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/IOSurface-NIJCMHTL7RQQ7H22MHGIH668.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/FileProvider-4MELQAHOVJ8VX5XIIP9QJFDG2.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Accessibility-1ES3RENUUD2Z5VPOUZLSWZKIW.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreData-631OX48XW1PB8P50U0PBJH4GZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/OpenGLES-B4B947OJV4FFYN08HPWJDVKS0.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Metal-2TV4A04UPMQRLZA0MEV4DSRJ3.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Network-1KLMR386TJ03JZJMBGKUJMHJ7.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Symbols-6UMQFNDYEQ5Z34DIXAAFBE4AQ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreTransferable-36RYG7CUQ3BQ3M5LT51N15Y24.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UserNotifications-AD9WKJQ1LNVCF7K8IXTCPVWPT.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/OSLog-IFF232TGPWGV19HWVY2Z1LP7.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UIUtilities-2SA7X6QPHW2SYMOW049KHIKZX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreVideo-8EJEB1ZAMNBK9WOWQF1PCTJRU.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/QuartzCore-28UPFOCV9SJWC0NGU6DSY8X7S.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreImage-41X4TSQYTL5Z0LXZVQ4BE9KJJ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftUICore-7CNG9E9BUQGJCB2ABVI826VQB.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UIKit-7L9GZOZYGXNDQERTWU5WGJSWK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/WebKit-7U3JZ7R9XCZ73CX3O6HBO7KB7.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftUI-99TSJJW83RSMIK1O5GQJXDY17.pcm

SwiftCompile normal arm64 Compiling\ App.swift,\ AppSession.swift,\ JSBridge.swift,\ KeychainStore.swift,\ MarketplaceTab.swift,\ MessagesTab.swift,\ ProfileTab.swift,\ PushDelegate.swift,\ WorldTab.swift,\ GeneratedAssetSymbols.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/App.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Auth/AppSession.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Bridge/JSBridge.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Auth/KeychainStore.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/MarketplaceTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/MessagesTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/ProfileTab.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Push/PushDelegate.swift /Users/runner/work/like-art-ios/like-art-ios/ios-b2/Sources/Tabs/WorldTab.swift /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/GeneratedAssetSymbols.swift /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation2.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/ObjectiveC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreText.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/OSLog.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreImage.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/WebKit.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/UIKit.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Metal.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/simd.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/System.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Combine.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Symbols.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreFoundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/FileProvider.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreGraphics.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreVideo.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_Concurrency.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Darwin.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/DataDetection.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_Builtin_float.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/XPC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Foundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Accessibility.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_StringProcessing.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_WebKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/UniformTypeIdentifiers.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreTransferable.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/QuartzCore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Spatial.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/DeveloperToolsSupport.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation3.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/os.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Swift.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Dispatch.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/LocalAuthentication.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/CoreData.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Distributed.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Network.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/Observation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.2/_DarwinFoundation1.swiftmodule/arm64e-apple-ios.swiftmodule /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_tgmath-AHAP65LMXJS8ZTBGQ5B39QIK6.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreImage-41X4TSQYTL5Z0LXZVQ4BE9KJJ.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Symbols-6UMQFNDYEQ5Z34DIXAAFBE4AQ.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/FileProvider-4MELQAHOVJ8VX5XIIP9QJFDG2.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_SwiftConcurrencyShims-5M2E6NYWF7WHRNPE9M3NRLZH0.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation2-9JX2D1281Q0XH8CM3LQ2737PD.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ptrcheck-1HIKBYLY7BD7BK2PKP5FSL4FM.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ImageIO-7OPD7WHSN743XN01WY7DG9EU3.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_inttypes-3OBPYU86LQVMHE4ALFULA429D.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftUI-99TSJJW83RSMIK1O5GQJXDY17.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/IOSurface-NIJCMHTL7RQQ7H22MHGIH668.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/LocalAuthentication-B96FLNGGYONCUTFRZKAGUIQBN.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdarg-57H4QFD9B934F5ZYBYG28698J.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/XPC-8TO1KJNLLR6LO820J48QIMJU4.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/WebKit-7U3JZ7R9XCZ73CX3O6HBO7KB7.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Foundation-9PFEAT7JAOD51MPKB0F9Z5KCF.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CFNetwork-4UOIK5028KAN7Q8Y076ZUDYMB.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_intrinsics-2WQ78P0CTVC5LQGLTTCIOQ55W.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/sys_types-BPLASASPFW8M9Z4BFTNEUTF7V.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreVideo-8EJEB1ZAMNBK9WOWQF1PCTJRU.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation1-6ZU0UEPX0G9XJUA5ALZRSZOMT.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stddef-MBBM0180A1YES5J798B0CHC2.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftShims-1MABNWY2W4HF8PYUD6BPT5TAZ.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/QuartzCore-28UPFOCV9SJWC0NGU6DSY8X7S.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Security-5XUAQK7VBDU1X4SKPR8PJS6QH.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdatomic-CSOPI357L8ONDB1EBUOD7GGZ6.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UIKit-7L9GZOZYGXNDQERTWU5WGJSWK.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreText-AHV2MNP8KH5HHMCJ6DHNL3VTF.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Network-1KLMR386TJ03JZJMBGKUJMHJ7.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/DeveloperToolsSupport-D568ZZV5GGF0HFGCU6IJBWL0Y.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os-8RBHLU86HK0KJ848VCDJH62IH.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os_workgroup-392XDKSQMB85FF3G5JXC01S1T.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/simd-BE08MGU4C70SIZN7WRMT4C662.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreGraphics-17XONOP6U10SWL9IVBVYY65CS.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_limits-E4B238HZGLY1ZAM9HGAUL5BZC.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreTransferable-36RYG7CUQ3BQ3M5LT51N15Y24.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UserNotifications-AD9WKJQ1LNVCF7K8IXTCPVWPT.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_AvailabilityInternal-EHRSA4T93JD5QEUGJ4PTAI3M8.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Accessibility-1ES3RENUUD2Z5VPOUZLSWZKIW.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreData-631OX48XW1PB8P50U0PBJH4GZ.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_float-AYIK33CJ5ACSJYYNVVDLG5TDC.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/os_object-8RQH58KNMHJU51VUJA5Q8688F.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/OpenGLES-B4B947OJV4FFYN08HPWJDVKS0.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UniformTypeIdentifiers-DDGLRV6HLNJZ1RCIBZ0HQQ34P.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_DarwinFoundation3-4BB489964JBZUNHUM48O90AUK.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ptrauth-6TNDJ1I13XOQELTZ0D2F0AORS.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/MachO-91TI5A8RJI2RE5HWSKR7FYB9K.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/CoreFoundation-9DR2Q8H3U186RZ580BJVU3O70.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/OSLog-IFF232TGPWGV19HWVY2Z1LP7.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/DataDetection-4GEOMCRCQ37HCQS5BGMAE1UVW.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/dnssd-ENOAOW24RM779HUEVVAVECC3X.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdint-6RPBNTXHWM32RJJKSQ33YGSGY.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/UIUtilities-2SA7X6QPHW2SYMOW049KHIKZX.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/ObjectiveC-DST8KR6FLTFFLUW0FTUVWTU99.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Dispatch-DUVR2OTVRYC037CNRE6II4GNY.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Metal-2TV4A04UPMQRLZA0MEV4DSRJ3.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Darwin-19GMPWSXGL9FC52TDPWRSZ9XN.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Spatial-AN6YBETRUBDVKVFEUPPTKNAQX.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/_Builtin_stdbool-1LLN5I6AFV2FB1ULCXWW6LIU2.pcm /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/SwiftUICore-7CNG9E9BUQGJCB2ABVI826VQB.pcm /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-dependencies-1.json (in target 'LikeArt' from project 'LikeArt')

CompileSwift normal arm64 (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    

SwiftDriverJobDiscovery normal arm64 Compiling App.swift, AppSession.swift, JSBridge.swift, KeychainStore.swift, MarketplaceTab.swift, MessagesTab.swift, ProfileTab.swift, PushDelegate.swift, WorldTab.swift, GeneratedAssetSymbols.swift (in target 'LikeArt' from project 'LikeArt')

SwiftDriver\ Compilation\ Requirements LikeArt normal arm64 com.apple.xcode.tools.swift.compiler (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-Swift-Compilation-Requirements -- /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name LikeArt -O -whole-module-optimization -enforce-exclusivity\=checked @/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -target arm64-apple-ios16.0 -g -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -F /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex/iphoneos26.2-23C57-dc75598d0054f22ec865fa860f139d722dd23b4ebda140f7210d155ff1243552.sdkstatcache -output-file-map /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-generated-files.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-own-target-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt-project-headers.hmap -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/include -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/arm64 -Xcc -I/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -working-directory /Users/runner/work/like-art-ios/like-art-ios/ios-b2 -no-emit-module-separately-wmo

SwiftMergeGeneratedHeaders /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/LikeArt-Swift.h /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-swiftHeaderTool -arch arm64 /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-Swift.h -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/DerivedSources/LikeArt-Swift.h

Copy /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftmodule /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftmodule

Copy /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftdoc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftdoc (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftdoc /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.swiftdoc

Copy /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.abi.json /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.abi.json (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.abi.json /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.swiftmodule/arm64-apple-ios.abi.json

Ld /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt normal (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -Xlinker -reproducible -target arm64-apple-ios16.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -Os -L/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/EagerLinkingTBDs/Release-iphoneos -L/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -F/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/EagerLinkingTBDs/Release-iphoneos -F/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos -filelist /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.LinkFileList -Xlinker -rpath -Xlinker /usr/lib/swift -Xlinker -rpath -Xlinker @executable_path/Frameworks -dead_strip -Xlinker -object_path_lto -Xlinker /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_lto.o -Xlinker -final_output -Xlinker /Applications/LikeArt.app/LikeArt -Xlinker -dependency_info -Xlinker /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_dependency_info.dat -fobjc-link-runtime -L/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos -L/usr/lib/swift -Xlinker -add_ast_path -Xlinker /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.swiftmodule @/Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt-linker-args.resp -Xlinker -no_adhoc_codesign -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt

CopySwiftLibs /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-swiftStdLibTool --copy --verbose --sign 4724763DF7F78CA5FC13AC7400114BFCB07EAC07 --scan-executable /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt --scan-folder /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Frameworks --scan-folder /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/PlugIns --scan-folder /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/SystemExtensions --scan-folder /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Extensions --platform iphoneos --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.USh6n7/Metal.xctoolchain --toolchain /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Frameworks --unsigned-destination /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/SwiftSupport --strip-bitcode --strip-bitcode-tool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span

ExtractAppIntentsMetadata (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor --toolchain-dir /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.USh6n7/Metal.xctoolchain --module-name LikeArt --sdk-root /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk --xcode-version 17C529 --platform-family iOS --deployment-target 16.0 --bundle-identifier com.likeart.app --output /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app --target-triple arm64-apple-ios16.0 --binary-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt --dependency-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt_dependency_info.dat --stringsdata-file /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/ExtractedAppShortcutsMetadata.stringsdata --source-file-list /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftFileList --metadata-file-list /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList --static-metadata-file-list /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyStaticMetadataFileList --swift-const-vals-list /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/Objects-normal/arm64/LikeArt.SwiftConstValuesFileList --compile-time-extraction --deployment-aware-processing --validate-assistant-intents --no-app-shortcuts-localization
2026-09-17 01:53:34.822 appintentsmetadataprocessor[7053:24105] Starting appintentsmetadataprocessor export
2026-09-17 01:53:34.833 appintentsmetadataprocessor[7053:24105] warning: Metadata extraction skipped. No AppIntents.framework dependency found.

GenerateDSYMFile /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.app.dSYM /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/dsymutil /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt -o /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/BuildProductsPath/Release-iphoneos/LikeArt.app.dSYM

AppIntentsSSUTraining (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor --infoplist-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Info.plist --temp-dir-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/ssu --bundle-id com.likeart.app --product-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app --extracted-metadata-path /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/Metadata.appintents --deployment-postprocessing --metadata-file-list /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.DependencyMetadataFileList --archive-ssu-assets
2026-09-17 01:53:34.904 appintentsnltrainingprocessor[7060:24119] Parsing options for appintentsnltrainingprocessor
2026-09-17 01:53:34.907 appintentsnltrainingprocessor[7060:24119] No AppShortcuts found - Skipping.

Strip /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip -D /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app/LikeArt

SetOwnerAndGroup runner:staff /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /usr/sbin/chown -RH runner:staff /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

SetMode u+w,go-w,a+rX /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /bin/chmod -RH u+w,go-w,a+rX /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

CodeSign /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    
    Signing Identity:     "iPhone Distribution: ZHIJIAN TAN (2JZCL349AG)"
    Provisioning Profile: "LikeArt App Store"
                          (fad0d533-ab97-48d8-8a60-944c6f3b91af)
    
    /usr/bin/codesign --force --sign 4724763DF7F78CA5FC13AC7400114BFCB07EAC07 --entitlements /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/IntermediateBuildFilesPath/LikeArt.build/Release-iphoneos/LikeArt.build/LikeArt.app.xcent --generate-entitlement-der /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

RegisterExecutionPolicyException /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-RegisterExecutionPolicyException /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

Validate /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    builtin-validationUtility /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app -shallow-bundle -infoplist-subpath Info.plist

Touch /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app (in target 'LikeArt' from project 'LikeArt')
    cd /Users/runner/work/like-art-ios/like-art-ios/ios-b2
    /usr/bin/touch -c /Users/runner/Library/Developer/Xcode/DerivedData/LikeArt-dsrrfznxtvpqjzfjbfwlsaburfwr/Build/Intermediates.noindex/ArchiveIntermediates/LikeArt/InstallationBuildProductsLocation/Applications/LikeArt.app

** ARCHIVE SUCCEEDED **
```

</details>

<details><summary>export.txt</summary>

### export.txt

```text
2026-09-17 01:53:37.346 xcodebuild[7069:24168] [MT] IDEDistribution: -[IDEDistributionLogging _createLoggingBundleAtPath:]: Created bundle at path "/var/folders/nj/vtw8zd2j31d1gdrtntc5y4600000gn/T/LikeArt_2026-09-17_01-53-37.340.xcdistributionlogs".
Exported LikeArt to: /Users/runner/work/like-art-ios/like-art-ios/build-b2/export
** EXPORT SUCCEEDED **
```

</details>
