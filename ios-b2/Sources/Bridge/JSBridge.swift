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
  // The 3D world continuously mutates its HUD, chat and loading DOM. It has
  // no auction entry points, so do not install this observer there at all.
  if (location.pathname.startsWith('/v6')) return;
  try { sessionStorage.setItem('likeart_ios_app', '1'); } catch (_) {}
  const RE_TEXT = /拍卖|竞拍|喜欢就出价|出价|auction|аукцион|\bbid(?:s|ding)?\b|オークション|入札|경매|입찰/i;
  const CONTROL_SELECTOR = 'a[href],button,[role="button"],[role="link"],[onclick],.cursor-pointer';
  const isAuctionPath = (url) => {
    try { return /\/(?:auctions|auction-permissions)/i.test(decodeURIComponent(new URL(url, location.href).pathname)); }
    catch (_) { return false; }
  };
  const hide = (element) => element.style.setProperty('display', 'none', 'important');
  const inspectText = (node) => {
    const parent = node.parentElement;
    if (!parent || parent.closest('script,style,textarea') || !RE_TEXT.test(node.textContent || '')) return;
    hide(parent.closest('a,button,[role="button"],[role="link"],[onclick],.cursor-pointer') || parent);
  };
  const inspectElement = (element) => {
    if (element.matches('a[href]') && isAuctionPath(element.href)) hide(element);
    for (const control of element.querySelectorAll(CONTROL_SELECTOR)) {
      if (control.matches('a[href]') && isAuctionPath(control.href)) hide(control);
    }
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) inspectText(walker.currentNode);
  };
  const inspectNode = (node) => {
    if (node.nodeType === Node.TEXT_NODE) inspectText(node);
    else if (node.nodeType === Node.ELEMENT_NODE) inspectElement(node);
  };
  const initialScan = () => {
    if (!document.body) return;
    // Existing controls are checked once. Future work is restricted to each
    // subtree delivered through MutationRecord.addedNodes below.
    for (const control of document.querySelectorAll(CONTROL_SELECTOR)) {
      if (control.parentElement && control.parentElement.closest(CONTROL_SELECTOR)) continue;
      inspectElement(control);
    }
  };
  let pendingNodes = new Set();
  let scheduled = false;
  function killNode() {
    scheduled = false;
    const nodes = pendingNodes;
    pendingNodes = new Set();
    for (const node of nodes) inspectNode(node);
  }
  const scheduleKill = () => {
    if (scheduled) return;
    scheduled = true;
    const run = () => killNode();
    if (typeof requestIdleCallback === 'function') requestIdleCallback(run, { timeout: 250 });
    else setTimeout(run, 200);
  };
  const observer = new MutationObserver((records) => {
    for (const record of records) {
      for (const node of record.addedNodes) pendingNodes.add(node);
    }
    if (pendingNodes.size) scheduleKill();
  });
  observer.observe(document, { childList: true, subtree: true });
  initialScan();
  checkLocation();
  function checkLocation() { if (isAuctionPath(location.href)) location.replace('/'); }
  window.addEventListener('popstate', checkLocation);
  for (const method of ['pushState', 'replaceState']) {
    const original = history[method];
    history[method] = function(s, t, u) {
      if (u != null && isAuctionPath(String(u))) { location.replace('/'); return; }
      return original.apply(this, arguments);
    };
  }
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
