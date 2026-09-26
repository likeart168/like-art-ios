import SwiftUI
import WebKit

struct MarketplaceTab: View {
    var body: some View { WebTab(url: URL(string: "https://like-art.com/?app=1")!, title: tr("商城", "Shop", "Магазин"), tab: 0) }
}

@MainActor
final class WebState: ObservableObject {
    @Published var loading = true
    @Published var failed = false
    @Published var reload = UUID()
    weak var view: WKWebView?
}

struct WebTab: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var state = WebState()
    let url: URL
    let title: String
    let tab: Int
    var body: some View {
        NavigationStack {
            ZStack {
                WebContent(url: url, tab: tab, state: state).id(session.revision)
                if state.loading || state.failed {
                    VStack(spacing: 18) {
                        Image(systemName: state.failed ? "wifi.slash" : "bag").font(.largeTitle)
                        Text("Like Art").font(.title.bold())
                        if state.failed {
                            Text(tr("网络不可用，可查看已保存的消息和账户。", "You are offline. Saved messages and account details remain available.", "Нет сети. Сохранённые сообщения и данные профиля доступны."))
                            Button(tr("重试", "Retry", "Повторить")) { state.reload = UUID() }
                            Button(tr("离线内容", "Offline content", "Офлайн-данные")) { session.selectedTab = 3 }
                        } else {
                            ProgressView()
                            Text(tr("正在加载…", "Loading…", "Загрузка…"))
                        }
                    }.multilineTextAlignment(.center).padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { state.view?.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel(tr("返回", "Back", "Назад")) }
                ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: state.view?.url ?? url) }
            }
        }
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
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = "LikeArtApp/1.0"
        configuration.userContentController.add(context.coordinator.bridge, name: "likeArtSession")
        configuration.userContentController.addUserScript(WKUserScript(source: JSBridge.script(token: session.token), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        state.view = view
        context.coordinator.bridge.webView = view
        context.coordinator.reload = state.reload
        view.evaluateJavaScript("navigator.userAgent") { value, _ in
            if let ua = value as? String { view.customUserAgent = ua.contains("LikeArtApp/1.0") ? ua : ua + " LikeArtApp/1.0" }
            view.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
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
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "likeArtSession")
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let state: WebState
        let bridge = JSBridge()
        var reload = UUID()
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
