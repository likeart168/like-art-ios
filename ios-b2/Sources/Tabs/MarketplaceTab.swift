import SwiftUI
import WebKit

// APPWORLD212: the bundled inventory is verified byte-for-byte against the live origin.
enum NativeReleasePolicy {
    static let bundledWorldPackEnabled = true
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
    @Published var failureReason = ""
    @Published var retryAttempts = 0
    @Published var retryPending = false
    private var retryTask: Task<Void, Never>?
    func retry() {
        guard failed, !retryPending, retryAttempts < 3 else { return }
        retryAttempts += 1; retryPending = true
        let delay = UInt64(1 << (retryAttempts - 1)) * 1_000_000_000
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            self.retryPending = false; self.reload = UUID()
        }
    }
    func cancelRetry() { retryTask?.cancel(); retryTask = nil; retryPending = false }
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

    private var clipsImmersive: Bool {
        let current = state.currentURL ?? url
        guard AppSession.allowed(current) else { return false }
        let path = current.path
        return path == "/clips" || (path.hasPrefix("/clips/") && path != "/clips/upload" && !path.hasPrefix("/clips/upload/")) || path == "/v6/clips/watch.html"
    }

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
                WebContent(url: url, tab: tab, state: state, clipsImmersive: clipsImmersive)
                    .id(session.revision)
                    .ignoresSafeArea(.container, edges: clipsImmersive ? .vertical : [])
                if state.loading || state.failed {
                    VStack(spacing: 22) {
                        BrandMark(size: 88)
                        Text("Like Art").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(AppTheme.ink)
                        if state.failed {
                            Text(tr("页面未能打开", "Page could not open", "Не удалось открыть страницу")).font(.headline)
                            Text(state.failureReason).font(.subheadline).foregroundStyle(AppTheme.muted)
                            Button(state.retryPending ? tr("正在等待重试…", "Waiting to retry…", "Ожидание повтора…") : tr("重新连接", "Try again", "Попробовать снова")) { state.retry() }.buttonStyle(ArtPrimaryButton())
                                .disabled(state.retryPending || state.retryAttempts >= 3)
                            if state.retryAttempts >= 3 { Text(tr("已连续重试三次，请稍后再打开。", "Three retries used. Please try again later.", "Три попытки использованы. Повторите позже.")) }
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
            .toolbarBackground(clipsImmersive ? .hidden : .visible, for: .navigationBar, .tabBar)
            .toolbarColorScheme(clipsImmersive ? .dark : nil, for: .navigationBar, .tabBar)
            .tint(clipsImmersive ? .white : AppTheme.tint)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { state.view?.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel(tr("返回", "Back", "Назад")) }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(clipsImmersive ? .white : AppTheme.tint).font(.caption)
                        Text(pageTitle).font(.system(.headline, design: .rounded)).foregroundStyle(clipsImmersive ? .white : AppTheme.ink).lineLimit(1)
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
    let clipsImmersive: Bool
    func makeCoordinator() -> Coordinator { Coordinator(state: state) }
    func makeUIView(context: Context) -> WKWebView {
        let initialTarget = session.selectedTab == tab && session.destinationTab == tab ? (session.destination ?? url) : url
        let isWorldEntry = ["/v6", "/v6/", "/v6/index.html"].contains(initialTarget.path)
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
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1" {
            configuration.userContentController.addUserScript(WKUserScript(source: WorldCaptureProbe.errorScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        #endif
        configuration.applicationNameForUserAgent = "LikeArtApp/1.0"
        configuration.userContentController.add(context.coordinator.bridge, name: "likeArtSession")
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.script(token: session.token), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.auctionKillJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // A197: V6 基础资源包 —— 自定义 scheme + 世界页 JS 改写的请求拦截（安卓 WorldPack.java 同源）
        if NativeReleasePolicy.bundledWorldPackEnabled && isWorldEntry {
            configuration.setURLSchemeHandler(PackSchemeHandler(), forURLScheme: PackSchemeHandler.scheme)
            configuration.userContentController.addUserScript(
                WKUserScript(source: PackShim.script(entries: PackShim.bundledEntries), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let view = ClipsViewportWebView(frame: .zero, configuration: configuration)
        view.clipsImmersive = clipsImmersive
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
        let load = {
            guard !context.coordinator.initialNavigationStarted else { return }
            context.coordinator.initialNavigationStarted = true
            let target = session.selectedTab == tab && session.destinationTab == tab ? (session.destination ?? url) : url
            if session.selectedTab == tab && session.destinationTab == tab { context.coordinator.destination = session.destination }
            view.load(URLRequest(url: target, cachePolicy: .useProtocolCachePolicy))
        }
        if isWorldEntry {
            // applicationNameForUserAgent supplies the app suffix without a JS round trip.
            load()
        } else {
            view.evaluateJavaScript("navigator.userAgent") { value, _ in
                if let ua = value as? String { view.customUserAgent = ua.contains("LikeArtApp/1.0") ? ua : ua + " LikeArtApp/1.0" }
                load()
            }
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if let clipsView = view as? ClipsViewportWebView { clipsView.clipsImmersive = clipsImmersive }
        if let destination = session.destination, session.destinationTab == tab, session.selectedTab == tab, destination != context.coordinator.destination {
            context.coordinator.destination = destination
            context.coordinator.initialNavigationStarted = true
            view.load(URLRequest(url: destination))
        }
        if context.coordinator.reload != state.reload {
            context.coordinator.reload = state.reload
            context.coordinator.initialNavigationStarted = true
            view.load(URLRequest(url: view.url ?? url))
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.urlObservation?.invalidate()
        coordinator.state.cancelRetry()
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "likeArtSession")
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let state: WebState
        let bridge = JSBridge()
        var reload = UUID()
        var urlObservation: NSKeyValueObservation?
        var destination: URL?
        var initialNavigationStarted = false
        weak var currentNavigation: WKNavigation?
        #if DEBUG
        let worldCapture = WorldCaptureProbe()
        #endif
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
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            currentNavigation = navigation; state.cancelRetry()
            state.loading = true; state.failed = false; state.failureReason = ""
            #if DEBUG
            worldCapture.start(webView, state: state)
            #endif
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === currentNavigation, !state.failed else { return }
            state.loading = false; bridge.refresh()
            (webView as? ClipsViewportWebView)?.syncClipsInsets(force: true)
            #if DEBUG
            scheduleClipsCaptureProbe(webView)
            #endif
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { guard navigation === currentNavigation else { return }; fail(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { guard navigation === currentNavigation else { return }; fail(error) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.cancelRetry(); state.loading = false; state.failed = true
            state.failureReason = tr("页面渲染进程意外停止。", "The page renderer stopped unexpectedly.", "Процесс отображения страницы неожиданно остановлен.") + " (WebKit renderer terminated)"
            if let path = webView.url?.path, path.hasPrefix("/v6/"), !path.hasPrefix("/v6/live/"), !path.hasPrefix("/v6/clips/") {
                state.failureReason += tr(" 请关闭其他应用后重试。", " Close other apps and retry.", " Закройте другие приложения и повторите.")
            }
            NSLog("[WorldEntry20] WebKit renderer terminated path=%@", webView.url?.path ?? "")
            #if DEBUG
            worldCapture.terminated()
            #endif
        }
        func fail(_ error: Error) {
            let detail = error as NSError
            if detail.domain == NSURLErrorDomain && detail.code == NSURLErrorCancelled { return }
            state.cancelRetry(); state.loading = false; state.failed = true
            state.failureReason = "\(detail.localizedDescription) (\(detail.domain) \(detail.code))"
            NSLog("[WorldEntry20] navigation failure domain=%@ code=%ld", detail.domain, detail.code)
        }
    }
}

// IMMERSIVE19: extend the video beneath native bars, while keeping the webpage
// controls inside their real safe area. Same-origin child frames request refresh.
@MainActor
final class ClipsViewportWebView: WKWebView {
    var clipsImmersive = false {
        didSet {
            guard clipsImmersive != oldValue else { return }
            scrollView.contentInsetAdjustmentBehavior = clipsImmersive ? .never : .automatic
            lastInsets = nil
            setNeedsLayout()
            syncClipsInsets(force: true)
        }
    }
    #if DEBUG
    var captureProbeStarted = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { scheduleClipsCaptureProbe(self) }
    }
    #endif
    private var lastInsets: String?
    override func layoutSubviews() {
        super.layoutSubviews()
        syncClipsInsets()
    }
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        syncClipsInsets(force: true)
    }
    func syncClipsInsets(force: Bool = false) {
        guard clipsImmersive, let current = url, AppSession.allowed(current) else { return }
        let top = max(0, safeAreaInsets.top), bottom = max(0, safeAreaInsets.bottom)
        let signature = "\(top):\(bottom):\(bounds.width):\(bounds.height):\(current.absoluteString)"
        guard force || lastInsets != signature else { return }
        lastInsets = signature
        let script = """
        (() => {
          const data = {type:'likeart-clips-insets-19',top:\(top),bottom:\(bottom)};
          window.__likeArtClipsInsets19 = data;
          if (!window.__likeArtClipsListener19) {
            window.__likeArtClipsListener19 = true;
            addEventListener('message', event => {
              if (event.origin !== location.origin || event.data?.type !== 'likeart-clips-ready-19') return;
              const frames = [...document.querySelectorAll('iframe')];
              if (frames.some(f => f.contentWindow === event.source)) event.source.postMessage(window.__likeArtClipsInsets19, location.origin);
            });
          }
          if (location.pathname === '/v6/clips/watch.html') window.postMessage(data, location.origin);
          for (const frame of document.querySelectorAll('iframe')) frame.contentWindow?.postMessage(data, location.origin);
        })();
        """
        evaluateJavaScript(script, completionHandler: nil)
    }
}
