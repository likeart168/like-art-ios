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
  const RE_TEXT = /(喜欢就出价|Place Your Bid|Сделайте ставку|我的拍卖|My Auctions|на аукцион|Auctions)/i;
  const KILL_TEXT = /(喜欢就出价|Place Your Bid|Сделайте ставку)/i;
  const RM_TEXT = /(我的拍卖|My Auctions|Моих аукционов|查看出价|出价记录)/i;
  const isAuctionPath = (p) => /^\/(auctions|account\/auctions)/.test(p || '');
  function killNode(node) {
    if (!node || !node.querySelectorAll) return;
    for (const a of node.querySelectorAll('a[href^="/auctions"],a[href^="/account/auctions"]')) a.remove();
    for (const b of node.querySelectorAll('header button,div[class*=grid] button,button')) {
      const t = (b.textContent || '').trim();
      if (KILL_TEXT.test(t)) b.remove();
    }
    for (const card of node.querySelectorAll('h3')) {
      const t = (card.textContent || '').trim();
      if (RM_TEXT.test(t)) {
        const box = card.closest('div.bg-white') || card.parentElement;
        if (box && box !== card) box.remove();
      }
    }
  }
  killNode(document);
  if (isAuctionPath(location.pathname)) { location.replace('/'); return; }
  const psh = history.pushState, rpl = history.replaceState;
  history.pushState = function (s, t, u) { if (isAuctionPath(String(u || ''))) { try { psh.call(history, s, t, '/'); location.assign('/'); } catch (e) {} return; } return psh.apply(history, arguments); };
  history.replaceState = function (s, t, u) { if (isAuctionPath(String(u || ''))) { try { rpl.call(history, s, t, '/'); location.assign('/'); } catch (e) {} return; } return rpl.apply(history, arguments); };
  let mq = 0;
  new MutationObserver(() => {
    if (mq) return; mq = 1; setTimeout(() => { mq = 0; killNode(document.documentElement); }, 150);
  }).observe(document, { childList: true, subtree: true });
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
