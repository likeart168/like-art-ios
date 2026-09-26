import Foundation
import WebKit

/// `likeartpack://local/v6/<entry>` → 从 App 内预装的 V6 基础资源包直接返回字节。
///
/// 🔴 为什么需要自定义 scheme：WKWebView **没有** 安卓 `shouldInterceptRequest(WebView, WebResourceRequest)`
/// 那样的 http(s) 拦截钩子（`WKURLSchemeHandler` 只对自定义 scheme 生效，对 https 注册会抛异常；
/// `NSURLProtocol` 拦不到 WKWebView 的网络进程）。因此 iOS 侧采取组合方案：
///   ① 页面层（`PackShim.swift` 注入的 JS）把命中包内条目的 `/v6/...` 请求改写成 `likeartpack://local/v6/...`；
///   ② 原生层（本类）把自定义 scheme 的请求变成对本地包的随机读。
/// 未命中条目 JS 不改写 → 原样走网络（语义与安卓一致）。
final class PackSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "likeartpack"
    static let host = "local"
    /// `likeartpack://local/v6/<entry>` 里前缀部分
    static let pathPrefix = "/v6/"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let key = Self.key(for: url) else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        guard let data = WorldPack.shared.data(for: key) else {
            // 未命中 / 包未就绪 → 让 JS 层回落原始 URL（绝不返回空响应，避免白屏）
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        var body = data
        var status = 200
        var headers: [String: String] = [
            "Content-Type": WorldPack.mime(key),
            "Content-Length": String(data.count),
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "public, max-age=31536000",
            "X-LikeArt-Pack": "hit",
            "Accept-Ranges": "bytes",
        ]
        if let range = task.request.value(forHTTPHeaderField: "Range"), range.hasPrefix("bytes=") {
            let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 2 {
                let start = parts[0].isEmpty ? max(0, data.count - (Int(parts[1]) ?? 0)) : (Int(parts[0]) ?? data.count)
                let end = parts[0].isEmpty || parts[1].isEmpty ? data.count - 1 : min(data.count - 1, Int(parts[1]) ?? -1)
                if start >= 0 && start <= end && start < data.count {
                    body = data.subdata(in: start..<(end + 1))
                    status = 206
                    headers["Content-Range"] = "bytes \(start)-\(end)/\(data.count)"
                } else {
                    status = 416
                    body = Data()
                    headers["Content-Range"] = "bytes */\(data.count)"
                }
            }
        }
        headers["Content-Length"] = String(body.count)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // 单次同步返回，无需中断处理
    }

    /// `likeartpack://local/v6/assets/x.glb` → `assets/x.glb`（相对 /v6/ 的条目名）
    static func key(for url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host == host else { return nil }
        var path = url.path                      // "/v6/assets/x.glb"
        if !path.hasPrefix(pathPrefix) { return nil }
        path = String(path.dropFirst(pathPrefix.count))
        guard !path.isEmpty, !path.contains("..") else { return nil }
        return path
    }
}
