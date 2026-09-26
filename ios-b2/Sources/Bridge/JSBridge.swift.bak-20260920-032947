import WebKit

@MainActor
final class JSBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    static func script(token: String) -> String {
        let payload: [String: String] = ["token": token, "platform": "ios", "lang": Locale.preferredLanguages.first ?? "en"]
        let json = String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
        return """
        (() => {
          if (location.protocol !== 'https:' || !['like-art.com','www.like-art.com'].includes(location.hostname)) return;
          window.LikeAppNative = \(json);
          if (!localStorage.getItem('auth_token') && window.LikeAppNative.token) localStorage.setItem('auth_token', window.LikeAppNative.token);
          const sync = () => {
            const token = localStorage.getItem('auth_token') || '';
            window.LikeAppNative.token = token;
            window.webkit.messageHandlers.likeArtSession.postMessage(token);
          };
          const originalSet = Storage.prototype.setItem;
          const originalRemove = Storage.prototype.removeItem;
          const originalClear = Storage.prototype.clear;
          Storage.prototype.setItem = function(k,v) { originalSet.call(this,k,v); if(this===localStorage && k==='auth_token') sync(); };
          Storage.prototype.removeItem = function(k) { originalRemove.call(this,k); if(this===localStorage && k==='auth_token') sync(); };
          Storage.prototype.clear = function() { originalClear.call(this); if(this===localStorage) sync(); };
          window.addEventListener('storage', sync);
          window.addEventListener('pageshow', sync);
          sync();
        })();
        """
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let url = message.frameInfo.request.url, AppSession.allowed(url),
              let value = message.body as? String, value.count < 16000 else { return }
        Task { await AppSession.shared.accept(value) }
    }
    func refresh() {
        guard let webView, let url = webView.url, AppSession.allowed(url) else { return }
        webView.evaluateJavaScript("window.LikeAppNative && window.webkit.messageHandlers.likeArtSession.postMessage(localStorage.getItem('auth_token') || '')", completionHandler: nil)
    }
}
