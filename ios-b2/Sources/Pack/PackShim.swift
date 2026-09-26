import Foundation

/// 注入到 App 内 `/v6/` 页面的 JS（document start）：
///   ① 退役网页层 Service Worker（App 里已预装资源包，避免重复下载 59 MiB + 双份缓存）
///   ② 把**命中包内条目**的 `/v6/<entry>` 请求改写成 `likeartpack://local/v6/<entry>`
///      → 由原生 `PackSchemeHandler` 从本地包随机读返回；
///      未命中的 URL 一个字都不改 → 原样走网络（与安卓 `shouldInterceptRequest` 语义一致）。
///
/// 🔴 安全底线：任何一个环节出错都必须**回落原始 URL**（fetch 失败重试原地址、XHR error 重发、
/// 图片 src 改写异常时用原值），绝不因为包的问题让页面白屏或资源加载失败。
enum PackShim {

    /// 生成注入脚本；`entries` = 包内条目清单（相对 `/v6/` 的路径）
    static func script(entries: [String]) -> String {
        let json: String
        if let data = try? JSONSerialization.data(withJSONObject: entries, options: []),
           let s = String(data: data, encoding: .utf8) {
            json = s
        } else {
            json = "[]"
        }
        return template.replacingOccurrences(of: "__ENTRIES__", with: json)
    }

    private static let template = #"""
    (function () {
      if (window.__v6PackShim) { return; }

      // ① App 内退役网页层 SW：原生已预装包，网页层再下一遍 = 白烧 59 MiB + 双份磁盘
      try {
        if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
          navigator.serviceWorker.getRegistrations().then(function (rs) {
            for (var i = 0; i < rs.length; i++) { try { rs[i].unregister(); } catch (e) {} }
          }).catch(function () {});
        }
      } catch (e) {}

      var ENTRIES = __ENTRIES__;
      var SCHEME_URL = 'likeartpack://local/v6/';
      var PREFIX = location.origin + '/v6/';
      var stats = { hits: 0, fallbacks: 0, entries: ENTRIES.length, ready: ENTRIES.length > 0 };
      window.__v6PackShim = stats;
      if (!ENTRIES.length || !window.fetch) { return; }

      var inPack = {};
      for (var i = 0; i < ENTRIES.length; i++) { inPack[ENTRIES[i]] = 1; }

      function rewrite(u) {
        if (typeof u !== 'string' || u.length < PREFIX.length || u.indexOf(PREFIX) !== 0) { return null; }
        var rest = u.slice(PREFIX.length);
        var cut = rest.length, q = rest.indexOf('?'), h = rest.indexOf('#');
        if (q >= 0 && q < cut) { cut = q; }
        if (h >= 0 && h < cut) { cut = h; }
        rest = rest.slice(0, cut);
        return inPack[rest] ? SCHEME_URL + rest : null;
      }

      // ② fetch
      var origFetch = window.fetch;
      if (typeof origFetch === 'function') {
        window.fetch = function (input, init) {
          var url = (typeof input === 'string') ? input : (input && input.url);
          var local = null;
          try { local = rewrite(url); } catch (e) { local = null; }
          if (local) {
            var o = init || {};
            // 不透明响应 / 带凭据 的语义会因跨源改写而变 → 这类请求不改写（走网络）
            if (o.mode !== 'no-cors' && o.credentials !== 'include') {
              var self = this, args = arguments;
              stats.hits++;
              return origFetch.call(this, local, init).catch(function () {
                stats.hits--; stats.fallbacks++;
                return origFetch.apply(self, args);
              });
            }
          }
          return origFetch.apply(this, arguments);
        };
      }

      // ③ XMLHttpRequest（three.js FileLoader 的兜底通道）
      var origOpen = XMLHttpRequest.prototype.open;
      var origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function (method, url) {
        var local = null;
        try { if (!this.withCredentials) { local = rewrite(url); } } catch (e) { local = null; }
        if (local) {
          stats.hits++;
          this.__v6PackMethod = method;
          this.__v6PackOriginal = url;
          this.__v6PackTried = false;
          var a = Array.prototype.slice.call(arguments);
          a[1] = local;
          return origOpen.apply(this, a);
        }
        return origOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function (body) {
        var xhr = this;
        if (xhr.__v6PackOriginal && !xhr.__v6PackTried) {
          xhr.addEventListener('error', function () {
            if (xhr.__v6PackTried) { return; }
            xhr.__v6PackTried = true;
            stats.hits--; stats.fallbacks++;
            try {
              origOpen.call(xhr, xhr.__v6PackMethod || 'GET', xhr.__v6PackOriginal);
              origSend.call(xhr, body);
            } catch (e) {}
          });
        }
        return origSend.apply(this, arguments);
      };

      // ④ <img src>（three.js TextureLoader / 贴图走 img 元素）
      try {
        var desc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
        if (desc && desc.set) {
          Object.defineProperty(HTMLImageElement.prototype, 'src', {
            configurable: true,
            enumerable: desc.enumerable,
            get: function () { return desc.get.call(this); },
            set: function (v) {
              var local = null;
              try { local = rewrite(v); } catch (e) { local = null; }
              if (local) { stats.hits++; try { return desc.set.call(this, local); } catch (e) {} }
              return desc.set.call(this, v);
            }
          });
        }
      } catch (e) {}
    })();
    """#
}
