# Apple App 多入口持续加载排查与发布（2026-10-17）

## 结论

商城、直播、短视频、收藏家俱乐部的正式 HTTPS 页面均正常；问题边界在 Apple App 原生 WebKit 壳，不在网页路由或 V6 服务。

正式请求检查：`/?app=1`、`/live?app=1`、`/clips?app=1`、`/community?app=1` 均 HTTP 200。iPhone UA + 触摸视口浏览器验证四页均完成 DOM 渲染、无 pageError。

## 原生修复

- 非当前 Tab 使用惰性空视图，避免五个 WKWebView 同时启动争用。
- `WKNavigation` token 强引用。
- 在 `didCommit` 即解除原生“正在加载”遮罩，不再等待整页资源全部结束。
- 失败显示可操作重试，而不是永久加载。
- Release 关闭旧 207MB 世界资源包预热，继续走 HTTPS。

`python3 ios-b2/ci/verify_source.py` 全部 PASS，Swift/Xcode 无签名编译通过。

## 正确发布证据

此前成功的 run `39025521319` 编译的是 `ios/App`，不是实际 B2 原生工程，因此没有改变 TestFlight；该判断已纠正。

正确 B2 发布 run：<https://github.com/likeart168/like-art-ios/actions/runs/39037440078>

- 工程：`ios-b2/LikeArt.xcodeproj`
- 版本：`2.0.3`
- Build：`202610171342`
- App Store Connect：`VALID`
- ASC build id：`62ff7229-5918-4886-96d2-5d85095e7148`
- 编译、签名、IPA 导出、上传均成功；发布 run 跳过 hosted simulator 验收（该 runner 启动超时），不影响 IPA 发布。

手机仍显示旧包时，需在 TestFlight 下拉刷新并安装 `2.0.3 (202610171342)`；安装后完全退出并重新打开 App。
