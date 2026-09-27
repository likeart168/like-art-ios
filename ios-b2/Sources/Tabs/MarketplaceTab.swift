import SwiftUI
import WebKit

// CLIPS17: keep the approved safe-build network path until pack acceptance.
enum NativeReleasePolicy {
    static let bundledWorldPackEnabled = false
}

struct MarketplaceTab: View {
    var body: some View { WebTab(url: URL(string: "https://like-art.com/?app=1")!, title: tr("商城", "Shop", "Магазин"), tab: 0) }
}

@MainActor
final class WebState: ObservableObject {
    @Published var loading = true
    @Published var failed = false
    @Published var reload = UUID()
    @Published var currentURL: URL?
    weak var view: WKWebView?
}

struct WebTab: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var state = WebState()
    @State private var profileVisible = false
    let url: URL
    let title: String
    let tab: Int

    private var pageTitle: String {
        let path = (state.currentURL ?? url).path
        if path.hasPrefix("/clips/upload") { return tr("发布视频", "Share a video", "Поделиться видео") }
        if path.hasPrefix("/clips") { return tr("短视频", "Clips", "Видео") }
        if path.hasPrefix("/community") { return tr("收藏家俱乐部", "Collectors Club", "Клуб коллекционеров") }
        if path.hasPrefix("/live") { return tr("直播", "Live", "Эфиры") }
        if path.hasPrefix("/login") { return tr("登录", "Sign in", "Вход") }
        if path.hasPrefix("/account") { return tr("我的", "My space", "Мой профиль") }
        if path.hasPrefix("/v6") { return tr("玩偶世界", "Doll World", "Мир кукол") }
        return title
    }

    // A195: 切 Tab / 进后台时挂起本 WebView 的音频（iOS WebView 在被遮挡时不自发 visibilitychange）
    private func applyAudioActive(_ active: Bool) {
        guard let view = state.view else { return }
        if active {
            if #available(iOS 15.0, *) { view.setAllMediaPlaybackSuspended(false, completionHandler: nil) }
            view.evaluateJavaScript("try{globalThis.__v6Bgm&&globalThis.__v6Bgm.resumeFromBackground&&globalThis.__v6Bgm.resumeFromBackground()}catch(e){}", completionHandler: nil)
        } else {
            view.evaluateJavaScript("try{globalThis.__v6Bgm&&globalThis.__v6Bgm.suspendForBackground&&globalThis.__v6Bgm.suspendForBackground()}catch(e){}", completionHandler: nil)
            if #available(iOS 15.0, *) { view.setAllMediaPlaybackSuspended(true, completionHandler: nil) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WebContent(url: url, tab: tab, state: state).id(session.revision)
                if state.loading || state.failed {
                    VStack(spacing: 22) {
                        BrandMark(size: 88)
                        Text("Like Art").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(AppTheme.ink)
                        if state.failed {
                            Text(tr("暂时无法连接", "A little pause", "Небольшая пауза")).font(.headline)
                            Text(tr("请检查网络后重试。保存的账户和消息仍可查看。", "Check your connection and try again. Your saved account and messages are still available.", "Проверьте подключение. Сохранённый профиль и сообщения по-прежнему доступны.")).font(.subheadline).foregroundStyle(AppTheme.muted)
                            Button(tr("重新连接", "Try again", "Попробовать снова")) { state.reload = UUID() }.buttonStyle(ArtPrimaryButton())
                            Button(tr("查看离线内容", "View saved content", "Сохранённые данные")) { profileVisible = true }.padding(10)
                        } else {
                            Text(tr("发现手作的温度", "A world of handmade wonder", "Мир искусства ручной работы")).font(.subheadline).foregroundStyle(AppTheme.muted)
                            ProgressView().tint(AppTheme.tint).padding(.top, 6)
                            Text(tr("正在加载…", "Loading…", "Загрузка…")).font(.caption).foregroundStyle(AppTheme.muted)
                        }
                    }.multilineTextAlignment(.center).padding(30).frame(maxWidth: 430)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(AppTheme.paper)
                }
            }
            .navigationTitle(pageTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { state.view?.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel(tr("返回", "Back", "Назад")) }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(AppTheme.tint).font(.caption)
                        Text(pageTitle).font(.system(.headline, design: .rounded)).foregroundStyle(AppTheme.ink).lineLimit(1)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ShareLink(item: state.view?.url ?? url)
                    Button { profileVisible = true } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel(tr("我的账户", "My account", "Мой профиль")).accessibilityIdentifier("native.profile")
                }
            }
        }
        .sheet(isPresented: $profileVisible) { ProfileTab().environmentObject(session) }
        .onChange(of: session.selectedTab) { newTab in applyAudioActive(newTab == tab && scenePhase == .active && !profileVisible) }
        .onChange(of: scenePhase) { phase in applyAudioActive(session.selectedTab == tab && phase == .active && !profileVisible) }
        .onAppear { applyAudioActive(session.selectedTab == tab && !profileVisible) }
        .onChange(of: profileVisible) { visible in applyAudioActive(!visible && session.selectedTab == tab && scenePhase == .active) }
    }
}

struct WebContent: UIViewRepresentable {
    @EnvironmentObject var session: AppSession
    let url: URL
    let tab: Int
    @ObservedObject var state: WebState
    func makeCoordinator() -> Coordinator { Coordinator(state: state) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // CLIPS16: keep visible video inline and let the page control autoplay.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        // Initial App language comes from the device; keep any saved website choice.
        let preferred = (Locale.preferredLanguages.first ?? "en").split(separator: "-").first.map(String.init) ?? "en"
        let language = ["zh", "en", "ru", "ja", "ko"].contains(preferred) ? preferred : "en"
        let languageScript = """
        try {
          if (!localStorage.getItem('app_locale') && !new URL(location.href).searchParams.has('lang')) {
            localStorage.setItem('app_locale', '\(language)');
            localStorage.setItem('app_locale_user_set', '1');
          }
        } catch (_) {}
        """
        configuration.userContentController.addUserScript(WKUserScript(source: languageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.applicationNameForUserAgent = "LikeArtApp/1.0"
        configuration.userContentController.add(context.coordinator.bridge, name: "likeArtSession")
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.script(token: session.token), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.auctionKillJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // A197: V6 基础资源包 —— 自定义 scheme + 世界页 JS 改写的请求拦截（安卓 WorldPack.java 同源）
        if NativeReleasePolicy.bundledWorldPackEnabled {
            configuration.setURLSchemeHandler(PackSchemeHandler(), forURLScheme: PackSchemeHandler.scheme)
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        state.view = view
        context.coordinator.urlObservation = view.observe(\.url, options: [.initial, .new]) { [weak state] webView, _ in
            let current = webView.url
            DispatchQueue.main.async { state?.currentURL = current }
        }
        context.coordinator.bridge.webView = view
        context.coordinator.reload = state.reload
        view.evaluateJavaScript("navigator.userAgent") { value, _ in
            if let ua = value as? String { view.customUserAgent = ua.contains("LikeArtApp/1.0") ? ua : ua + " LikeArtApp/1.0" }
            let load = { view.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy)) }
            if NativeReleasePolicy.bundledWorldPackEnabled && url.path.hasPrefix("/v6") && !url.path.hasPrefix("/v6/clips/") {
                // 世界页：先把包备好再加载，保证首启也能命中本地包（失败/超时则照常加载 → 回落网络）
                WorldPack.shared.prepareAsync { _ in
                    let entries = WorldPack.shared.entryNames()
                    view.configuration.userContentController.addUserScript(
                        WKUserScript(source: PackShim.script(entries: entries), injectionTime: .atDocumentStart, forMainFrameOnly: false))
                    NSLog("[WorldPack] world tab load entries=\(entries.count)")
                    load()
                }
            } else { load() }
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if let destination = session.destination, session.selectedTab == tab, destination != context.coordinator.destination {
            context.coordinator.destination = destination
            view.load(URLRequest(url: destination))
        }
        if context.coordinator.reload != state.reload {
            context.coordinator.reload = state.reload
            view.load(URLRequest(url: view.url ?? url))
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.urlObservation?.invalidate()
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "likeArtSession")
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let state: WebState
        let bridge = JSBridge()
        var reload = UUID()
        var urlObservation: NSKeyValueObservation?
        var destination: URL?
        init(state: WebState) { self.state = state }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            if AppSession.allowed(url) { decisionHandler(.allow); return }
            // Allow media subframes, but never grant them the native bridge.
            if action.targetFrame?.isMainFrame == false, ["https", "about", "blob"].contains(url.scheme ?? "") { decisionHandler(.allow); return }
            if ["https", "http", "mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, AppSession.allowed(url) { webView.load(action.request) }
            return nil
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { state.loading = true; state.failed = false }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { state.loading = false; bridge.refresh() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { state.loading = false; state.failed = true }
        func fail(_ error: Error) { if (error as NSError).code != NSURLErrorCancelled { state.loading = false; state.failed = true } }
    }
}
