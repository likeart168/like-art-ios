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
    static let auctionKillJS = #"""
(() => {
  if (!['like-art.com','www.like-art.com'].includes(location.hostname)) return;
  try { sessionStorage.setItem('likeart_ios_app', '1'); } catch (_) {}
  const RE_TEXT = /拍卖|竞拍|喜欢就出价|出价|auction|аукцион|\bbid(?:s|ding)?\b|オークション|入札|경매|입찰/i;
  const isAuctionPath = (url) => {
    try { return /\/(?:auctions|auction-permissions)/i.test(decodeURIComponent(new URL(url, location.href).pathname)); }
    catch (_) { return false; }
  };
  function killNode() {
    for (const a of document.querySelectorAll('a[href^="/auctions"],a[href^="/account/auctions"]')) a.remove();
    for (const a of document.querySelectorAll('a[href]')) {
      if (isAuctionPath(a.href)) a.style.setProperty('display', 'none', 'important');
    }
    if (!document.body) return;
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode, parent = node.parentElement;
      if (!parent || parent.closest('script,style,textarea') || !RE_TEXT.test(node.textContent || '')) continue;
      const target = parent.closest('a,button,[role="button"],[role="link"],[onclick],.cursor-pointer') || parent;
      target.style.setProperty('display', 'none', 'important');
    }
  }
  for (const method of ['pushState', 'replaceState']) {
    const original = history[method];
    history[method] = function(s, t, u) {
      if (u != null && isAuctionPath(String(u))) { location.replace('/'); return; }
      return original.apply(this, arguments);
    };
  }
  const checkLocation = () => { if (isAuctionPath(location.href)) location.replace('/'); };
  window.addEventListener('popstate', checkLocation);
  new MutationObserver(killNode).observe(document, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['href'] });
  killNode();
  checkLocation();
})();
"""#

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
