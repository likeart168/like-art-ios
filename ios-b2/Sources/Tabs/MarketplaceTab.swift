import SwiftUI
import WebKit

// WORLD22: the pinned pack is verified against the public byte inventory.
enum NativeReleasePolicy {
#if DEBUG
    // Reproduce the actually installed Clips17/19 build's network transport.
    static let bundledWorldPackEnabled = ProcessInfo.processInfo.environment["WORLD_CAPTURE_NO_PACK"] != "1"
#else
    // The last known-good 2.0.3 path used HTTPS for every WebView. The bundled
    // 207 MB archive previously caused real-device world crashes and startup
    // contention; keep it opt-in for diagnostics until a new device build proves
    // the pack path independently.
    static let bundledWorldPackEnabled = false
#endif

    static func packAllowed(for url: URL) -> Bool {
        guard bundledWorldPackEnabled else { return false }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "nopack" })?.value != "1"
    }
}

private enum WorldPackRecovery {
    static let messageName = "likeArtWorldPackRecovery"
    static let script = """
    (() => {
      const origin = location.origin;
      if ((origin !== 'https://like-art.com' && origin !== 'https://www.like-art.com') ||
          !location.pathname.startsWith('/v6/') ||
          location.pathname.startsWith('/v6/clips/') ||
          location.pathname.startsWith('/v6/live/') ||
          new URL(location.href).searchParams.get('nopack') === '1') return;
      let sent = false;
      const report = (reason) => {
        if (sent || !window.__v6PackShim) return;
        sent = true;
        window.webkit?.messageHandlers?.likeArtWorldPackRecovery?.postMessage({reason:String(reason || 'entry-failure')});
      };
      const check = () => {
        const entry = window.__V6_ENTRY__;
        const failure = entry && ((entry.failure === true) || (typeof entry.failure === 'string' && entry.failure) || (entry.failure && typeof entry.failure !== 'function') || (typeof entry.error === 'string' && entry.error));
        if (failure) return report(failure);
        if (window.__v6PackShim?.failures?.length && entry && entry.status === 'error') return report(entry.status);
        if (performance.now() > 180000 && window.ready !== true) return report('world-render-timeout');
        if (performance.now() > 180000 && window.ready === true && !document.querySelector('canvas')) return report('world-canvas-missing');
      };
      const timer = setInterval(check, 1000);
      setTimeout(() => clearInterval(timer), 182000);
      check();
    })();
    """
}

// Queue the latest destination until the WebView has started its first load.
// A SwiftUI update can arrive while makeUIView is constructing the view.
@MainActor
final class InitialWebNavigation {
    private(set) var prepared = false
    private var cancelled = false
    private var pending: URL?
    func request(_ url: URL) -> URL? {
        guard !cancelled else { return nil }
        if prepared { return url }
        pending = url
        return nil
    }
    func finish(defaultURL: URL) -> URL? {
        guard !cancelled, !prepared else { return nil }
        prepared = true
        let target = pending ?? defaultURL
        pending = nil
        return target
    }
    func cancel() { cancelled = true; pending = nil }
}

struct MarketplaceTab: View {
    var body: some View { WebTab(url: URL(string: "https://like-art.com/?app=1")!, title: tr("商城", "Shop", "Магазин"), tab: 0, tabKey: "shop") }
}

enum WebNavigationPolicy {
    static let maximumCoverDuration: TimeInterval = 180
    static let maximumRetries = 2
    static let retryInterval: TimeInterval = 30

    // activeProcessorCount is the native equivalent of hardwareConcurrency.
    static func timeout(for url: URL?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                        hardwareConcurrency: Int = ProcessInfo.processInfo.activeProcessorCount) -> TimeInterval {
        if let path = url?.path, path == "/v6" || path.contains("/v6/") { return 180 }
        return physicalMemory < 4 * 1024 * 1024 * 1024 || hardwareConcurrency <= 4 ? 120 : 60
    }

    static func request(_ url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) -> URLRequest {
        URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout(for: url))
    }
}

@MainActor
final class WebState: ObservableObject {
    @Published var loading = true
    @Published var failed = false
    @Published var reload = UUID()
    @Published var currentURL: URL?
    @Published var failureReason = ""
    @Published var retryPending = false
    @Published private(set) var retryAttempts: Int
    private(set) var coverDismissed = false
    var retryURL: URL?
    private let defaults: UserDefaults
    private let retryKey: String
    private var retryTask: Task<Void, Never>?
    init(tabKey: String = "shop", defaults: UserDefaults = .standard) {
        self.defaults = defaults
        retryKey = "LikeArt.navigationRetry.v1." + tabKey
        retryAttempts = (defaults.dictionary(forKey: retryKey)?["attempts"] as? Int) ?? 0
    }
    func dismissCover() { coverDismissed = true; loading = false }
    func showFailure(_ reason: String) {
        dismissCover()
        failed = true
        failureReason = reason
    }
    func beginNavigation() {
        cancelRetry()
        loading = !coverDismissed
        failed = false
        failureReason = ""
    }
    // Only a button calls this. Keep both the count and spacing across WebView,
    // tab and app recreation; successful loads do not silently refill the budget.
    func retry() {
        let saved = defaults.dictionary(forKey: retryKey) ?? [:]
        let attempts = (saved["attempts"] as? Int) ?? 0
        let last = (saved["lastRetryAt"] as? Double) ?? 0
        retryAttempts = attempts
        guard failed, !retryPending, attempts < WebNavigationPolicy.maximumRetries else { return }
        retryPending = true
        let now = Date().timeIntervalSince1970
        retryAttempts = attempts + 1
        defaults.set(["attempts": retryAttempts, "lastRetryAt": now], forKey: retryKey)
        let delay = max(0, WebNavigationPolicy.retryInterval - (now - last))
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.failed else { return }
            self.retryPending = false; self.reload = UUID()
        }
    }
    func cancelRetry() { retryTask?.cancel(); retryTask = nil; retryPending = false }
    weak var view: WKWebView?
}

struct WebTab: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var state: WebState
    @State private var profileVisible = false
    let url: URL
    let title: String
    let tab: Int
    let tabKey: String

    init(url: URL, title: String, tab: Int, tabKey: String) {
        self.url = url; self.title = title; self.tab = tab; self.tabKey = tabKey
        _state = StateObject(wrappedValue: WebState(tabKey: tabKey))
    }

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
                WebContent(url: url, tab: tab, tabKey: tabKey, state: state, clipsImmersive: clipsImmersive)
                    .id(session.revision)
                    .ignoresSafeArea(.container, edges: clipsImmersive ? .vertical : [])
                if state.loading {
                    VStack(spacing: 22) {
                        BrandMark(size: 88)
                        Text("Like Art").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(AppTheme.ink)
                        Text(tr("发现手作的温度", "A world of handmade wonder", "Мир искусства ручной работы")).font(.subheadline).foregroundStyle(AppTheme.muted)
                        ProgressView().tint(AppTheme.tint).padding(.top, 6)
                        Text(tr("正在加载…", "Loading…", "Загрузка…")).font(.caption).foregroundStyle(AppTheme.muted)
                    }.multilineTextAlignment(.center).padding(30).frame(maxWidth: 430)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(AppTheme.paper)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if state.failed {
                    VStack(spacing: 8) {
                        Text(state.failureReason).font(.caption).foregroundStyle(AppTheme.muted)
                        Button(state.retryPending ? tr("正在等待重试…", "Waiting to retry…", "Ожидание повтора…") : tr("重新连接", "Try again", "Попробовать снова")) { state.retry() }
                            .buttonStyle(ArtPrimaryButton())
                            .disabled(state.retryPending || state.retryAttempts >= WebNavigationPolicy.maximumRetries)
                        if state.retryAttempts >= WebNavigationPolicy.maximumRetries {
                            Text(tr("已用完两次重试。", "Both retries have been used.", "Обе попытки использованы.")).font(.caption)
                        }
                        Button(tr("查看离线内容", "View saved content", "Сохранённые данные")) { profileVisible = true }
                    }.multilineTextAlignment(.center).padding().frame(maxWidth: .infinity).background(AppTheme.paper)
                }
            }
            .overlay(alignment: .top) {
                if clipsImmersive && !state.loading && !state.failed {
                    HStack(spacing: 0) {
                        Button { state.view?.goBack() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel(tr("返回", "Back", "Назад"))
                        Spacer(minLength: 0)
                        ShareLink(item: state.view?.url ?? url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                        Button { profileVisible = true } label: { Image(systemName: "person.crop.circle").frame(width: 44, height: 44) }
                            .accessibilityLabel(tr("我的账户", "My account", "Мой профиль")).accessibilityIdentifier("native.profile")
                    }.foregroundStyle(.white).padding(.horizontal, 4)
                }
            }
            .navigationTitle(pageTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar(clipsImmersive ? .hidden : .visible, for: .navigationBar)
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
    let tabKey: String
    @ObservedObject var state: WebState
    let clipsImmersive: Bool
    func makeCoordinator() -> Coordinator { Coordinator(state: state, session: session, tabKey: tabKey, initialURL: url) }
    func makeUIView(context: Context) -> WKWebView {
        #if DEBUG
        if ["/v6", "/v6/", "/v6/index.html"].contains(url.path) {
            context.coordinator.worldCapture.markEntryRequested()
        }
        #endif
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
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1" {
            configuration.userContentController.addUserScript(WKUserScript(source: "window.__documentStart25=performance.now();", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        #endif
        configuration.userContentController.addUserScript(WKUserScript(source: languageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1" {
            configuration.userContentController.add(context.coordinator.worldCapture, name: "worldCaptureTrace")
            configuration.userContentController.addUserScript(WKUserScript(source: WorldCaptureProbe.errorScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        #endif
        configuration.applicationNameForUserAgent = "LikeArtApp/1.0"
        configuration.userContentController.add(context.coordinator.bridge, name: "likeArtSession")
        context.coordinator.syncSessionScript(session.token, controller: configuration.userContentController)
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.auctionKillJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // A197: V6 基础资源包 —— 自定义 scheme + 世界页 JS 改写的请求拦截（安卓 WorldPack.java 同源）
        if NativeReleasePolicy.packAllowed(for: url) {
            configuration.setURLSchemeHandler(PackSchemeHandler(), forURLScheme: PackSchemeHandler.scheme)
            configuration.userContentController.addScriptMessageHandler(PackMessageHandler(), contentWorld: .page, name: "likeArtWorldPack")
        }
        let packCandidate = url.path.hasPrefix("/v6") && !url.path.hasPrefix("/v6/clips/") && !url.path.hasPrefix("/v6/live/")
        if packCandidate && NativeReleasePolicy.packAllowed(for: url) {
            configuration.userContentController.add(context.coordinator, name: WorldPackRecovery.messageName)
            configuration.userContentController.addUserScript(WKUserScript(source: WorldPackRecovery.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let view = ClipsViewportWebView(frame: .zero, configuration: configuration)
        view.clipsImmersive = clipsImmersive
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        state.view = view
        #if DEBUG
        WorldCaptureProbe.register(view, tab: tab)
        #endif
        context.coordinator.urlObservation = view.observe(\.url, options: [.initial, .new]) { [weak coordinator = context.coordinator] webView, _ in
            let current = webView.url
            DispatchQueue.main.async { coordinator?.record(current) }
        }
        context.coordinator.bridge.webView = view
        context.coordinator.reload = state.reload
        // applicationNameForUserAgent already supplies the native marker. Do not
        // wait for an empty WebContent process/JS round trip before navigation.
        do {
            let load = {
                // A requested deep link wins over the initial tab URL.
                var target = session.tabNavigation.restore(for: tabKey, canonicalURL: url)
                if session.selectedTab == tab && session.destinationTab == tab,
                   let destination = session.destination, destination != context.coordinator.destination {
                    target = destination
                    context.coordinator.handle(destination)
                }
                guard let preparedTarget = context.coordinator.initialNavigation.finish(defaultURL: target) else { return }
                context.coordinator.markDestinationHandled()
                context.coordinator.startCoverWatchdog()
                view.load(WebNavigationPolicy.request(preparedTarget))
            }
            let worldPackCandidate = url.path.hasPrefix("/v6") && !url.path.hasPrefix("/v6/clips/") && !url.path.hasPrefix("/v6/live/")
            guard worldPackCandidate, NativeReleasePolicy.packAllowed(for: url) else { load(); return view }

            // Do not hold the first navigation behind the archive. A warm archive can
            // be installed before navigation; a cold archive leaves the network
            // navigation in place and remains available for a later user retry.
            let started = ProcessInfo.processInfo.systemUptime
            let installShim: () -> Bool = {
                guard !context.coordinator.disposed, session.selectedTab == tab,
                      !context.coordinator.packShimInstalled,
                      WorldPack.shared.isReady else { return false }
                let entries = WorldPack.shared.entryNames()
                guard !entries.isEmpty else { return false }
                let source = PackShim.script(entries: entries)
                guard !source.isEmpty else {
                    NSLog("[WorldPack] shim template unavailable; keeping network transport")
                    return false
                }
                view.configuration.userContentController.addUserScript(
                    WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
                context.coordinator.packShimInstalled = true
                NSLog("[WorldPack] world tab pack enabled entries=%d", entries.count)
                return true
            }
            if installShim() {
                load()
            } else {
                load()
                WorldPack.shared.prepareAsync { ready in
                    guard !context.coordinator.packDecisionMade else { return }
                    context.coordinator.packDecisionMade = true
                    let elapsed = ProcessInfo.processInfo.systemUptime - started
                    guard ready, elapsed <= 1.5, installShim(), !context.coordinator.packReloaded,
                          !state.coverDismissed, !state.failed else {
                        NSLog("[WorldPack] network fallback ready=%d elapsed=%.3f", ready ? 1 : 0, elapsed)
                        return
                    }
                    // The first request was deliberately allowed to start immediately.
                    // Do not replace it with a second navigation when the pack warms;
                    // a retry remains an explicit user action.
                    let current = view.url ?? url
                    guard current.path.hasPrefix("/v6"), !current.path.hasPrefix("/v6/clips/"), !current.path.hasPrefix("/v6/live/") else { return }
                    context.coordinator.packReloaded = true
                    NSLog("[WorldPack] verified within budget; keeping current navigation path=%@", current.path)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard !context.coordinator.packDecisionMade else { return }
                    context.coordinator.packDecisionMade = true
                    NSLog("[WorldPack] pack preparation exceeded 1.5s; session uses network")
                }
            }
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        guard session.selectedTab == tab, !context.coordinator.disposed else { return }
        if let clipsView = view as? ClipsViewportWebView { clipsView.clipsImmersive = clipsImmersive }
        context.coordinator.syncSessionScript(session.token, controller: view.configuration.userContentController)
        if let destination = session.destination, session.destinationTab == tab, session.selectedTab == tab, destination != context.coordinator.destination {
            context.coordinator.handle(destination)
            if let target = context.coordinator.initialNavigation.request(destination) {
                context.coordinator.markDestinationHandled()
                state.retryURL = nil
                view.load(WebNavigationPolicy.request(target))
            }
        }
        if context.coordinator.reload != state.reload {
            context.coordinator.reload = state.reload
            let retryTarget = state.retryURL ?? (view.url ?? session.tabNavigation.restore(for: tabKey, canonicalURL: url))
            if let target = context.coordinator.initialNavigation.request(retryTarget) {
                view.load(WebNavigationPolicy.request(target))
            }
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.disposed = true
        coordinator.cancelLoadingTimeout()
        coordinator.urlObservation?.invalidate()
        coordinator.state.cancelRetry()
        coordinator.initialNavigation.cancel()
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "likeArtSession")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "likeArtWorldPack", contentWorld: .page)
        view.configuration.userContentController.removeScriptMessageHandler(forName: WorldPackRecovery.messageName)
        #if DEBUG
        view.configuration.userContentController.removeScriptMessageHandler(forName: "worldCaptureTrace")
        #endif
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let state: WebState
        let bridge = JSBridge()
        let session: AppSession
        let tabKey: String
        let initialURL: URL
        let revision: UUID
        var disposed = false
        private var sessionScript: WKUserScript?
        private var scriptToken: String?
        var reload = UUID()
        var urlObservation: NSKeyValueObservation?
        var destination: URL?
        let initialNavigation = InitialWebNavigation()
        // Keep the token strongly until WebKit reports completion. WKNavigation is
        // not guaranteed to stay alive between didStart and didFinish; a weak token
        // made the native loading cover remain forever on otherwise healthy pages.
        var currentNavigation: WKNavigation?
        var packShimInstalled = false
        var packDecisionMade = false
        var packReloaded = false
        private var packRecoveryAttempted = false
        private var loadingTimeoutWorkItem: DispatchWorkItem?
        private var coverTimeoutWorkItem: DispatchWorkItem?
        #if DEBUG
        let worldCapture = WorldCaptureProbe()
        #endif
        init(state: WebState, session: AppSession, tabKey: String, initialURL: URL = URL(string: "https://like-art.com/?app=1")!) {
            self.state = state
            self.session = session
            self.tabKey = tabKey
            self.initialURL = initialURL
            revision = session.revision
            destination = session.tabNavigation.destination(for: tabKey)
        }
        func cancelLoadingTimeout() {
            loadingTimeoutWorkItem?.cancel()
            loadingTimeoutWorkItem = nil
            coverTimeoutWorkItem?.cancel()
            coverTimeoutWorkItem = nil
        }
        func startCoverWatchdog() {
            // One deadline for the initial cover, never extended by redirects or
            // repeated didStart callbacks. Also works if WebKit sends no callback.
            guard !state.coverDismissed, coverTimeoutWorkItem == nil else { return }
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, !self.disposed, self.state.loading else { return }
                self.showTimeout()
                NSLog("[LikeArt] loading cover reached 180s tab=%@", self.tabKey)
            }
            coverTimeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + WebNavigationPolicy.maximumCoverDuration, execute: timeout)
        }
        private func showTimeout() {
            state.cancelRetry()
            state.showFailure(tr("页面加载较慢，可继续等待或点击重试。", "The page is taking longer. Keep waiting or try again.", "Страница загружается долго. Подождите или повторите попытку."))
        }
        func handle(_ url: URL) {
            destination = url
        }
        func markDestinationHandled() {
            if let destination { session.tabNavigation.handled(destination, for: tabKey) }
        }
        func record(_ url: URL?) {
            // Ignore queued observations from a disposed view or a signed-out account.
            guard !disposed, revision == session.revision else { return }
            session.tabNavigation.record(url, for: tabKey)
            state.currentURL = url
        }
        func syncSessionScript(_ token: String, controller: WKUserContentController) {
            guard scriptToken != token else { return }
            let replacement = WKUserScript(source: JSBridge.script(token: token), injectionTime: .atDocumentStart, forMainFrameOnly: true)
            if let previous = sessionScript {
                // Preserve language, pack, media and capture scripts in their original order.
                let scripts = controller.userScripts.map { $0 === previous ? replacement : $0 }
                controller.removeAllUserScripts()
                scripts.forEach { controller.addUserScript($0) }
            } else { controller.addUserScript(replacement) }
            sessionScript = replacement
            scriptToken = token
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == WorldPackRecovery.messageName,
                  message.frameInfo.isMainFrame,
                  let webView = state.view,
                  !packRecoveryAttempted,
                  !disposed,
                  let current = webView.url,
                  NativeReleasePolicy.packAllowed(for: current) else { return }
            packRecoveryAttempted = true
            var components = URLComponents(url: current, resolvingAgainstBaseURL: false)
            var items = components?.queryItems ?? []
            items.removeAll { $0.name == "nopack" }
            items.append(URLQueryItem(name: "nopack", value: "1"))
            components?.queryItems = items
            guard let fallback = components?.url else { return }
            // Pack failures (including slow GPU startup) must never auto-navigate.
            // Preserve the nopack fallback for the user's bounded manual retry.
            state.retryURL = fallback
            cancelLoadingTimeout()
            state.showFailure(tr("世界加载较慢，可继续等待或点击重试。", "The world is taking longer. Keep waiting or try again.", "Мир загружается долго. Подождите или повторите попытку."))
            NSLog("[WorldPack] manual nopack retry available reason=%@", String(describing: message.body))
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            if AppSession.allowed(url) { decisionHandler(.allow); return }
            // Allow media subframes, but never grant them the native bridge.
            if action.targetFrame?.isMainFrame == false, ["https", "about", "blob"].contains(url.scheme ?? "") { decisionHandler(.allow); return }
            if ["https", "http", "mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, AppSession.allowed(url) {
                var request = action.request
                request.timeoutInterval = WebNavigationPolicy.timeout(for: url)
                webView.load(request)
            }
            return nil
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard !disposed else { return }
            currentNavigation = navigation
            state.beginNavigation()
            startCoverWatchdog()
            loadingTimeoutWorkItem?.cancel()
            guard let expectedNavigation = navigation else { return }
            let timeout = DispatchWorkItem { [weak self, weak webView, expectedNavigation] in
                guard let self, let webView,
                      !self.disposed, self.currentNavigation === expectedNavigation else { return }
                // End only the loading UI; do not cancel page requests or form submissions.
                self.showTimeout()
                NSLog("[LikeArt] navigation timeout path=%@", webView.url?.path ?? "")
            }
            loadingTimeoutWorkItem = timeout
            let budget = WebNavigationPolicy.timeout(for: webView.url ?? state.currentURL ?? initialURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + budget, execute: timeout)
            #if DEBUG
            worldCapture.start(webView, state: state)
            #endif
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !disposed, navigation === currentNavigation else { return }
            cancelLoadingTimeout()
            record(webView.url)
            state.cancelRetry()
            state.dismissCover(); state.failed = false; state.failureReason = ""; state.retryURL = nil
            bridge.refresh()
            (webView as? ClipsViewportWebView)?.syncClipsInsets(force: true)
            #if DEBUG
            scheduleClipsCaptureProbe(webView)
            #endif
        }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard !disposed, navigation === currentNavigation else { return }
            record(webView.url)
            // didCommit starts presenting the document; dismiss conservatively
            // without waiting for streaming subresources or GPU startup. Latch this
            // for this WebState so later starts cannot cover rendered content again.
            cancelLoadingTimeout()
            state.cancelRetry()
            state.dismissCover(); state.failed = false; state.failureReason = ""
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { guard navigation === currentNavigation else { return }; fail(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { guard navigation === currentNavigation else { return }; fail(error) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !disposed else { return }
            cancelLoadingTimeout()
            currentNavigation = nil
            state.cancelRetry()
            state.showFailure(tr("页面渲染进程意外停止。", "The page renderer stopped unexpectedly.", "Процесс отображения страницы неожиданно остановлен.") + " (WebKit renderer terminated)")
            NSLog("[WorldEntry20] WebKit renderer terminated path=%@", webView.url?.path ?? "")
            #if DEBUG
            worldCapture.terminated()
            #endif
        }
        func fail(_ error: Error) {
            guard !disposed else { return }
            let detail = error as NSError
            cancelLoadingTimeout()
            state.cancelRetry(); state.dismissCover()
            if detail.domain == NSURLErrorDomain && detail.code == NSURLErrorCancelled { return }
            state.showFailure("\(detail.localizedDescription) (\(detail.domain) \(detail.code))")
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
          const data = {type:'likeart-clips-insets-19',top:\(top),bottom:\(bottom),compactHeader:true};
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
