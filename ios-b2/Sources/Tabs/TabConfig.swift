import Foundation
import Combine

/// A196: 一个底部菜单项（服务端配置下发）
struct AppTabItem: Identifiable, Equatable {
    let key: String
    let slot: Int
    let kind: String          // web | native
    let url: String?
    let nativeKey: String?
    let labels: [String: String]
    let icon: String

    var id: String { key }

    /// 按设备语言取名称（俄语优先于英语，避免中文强插）
    func labelText() -> String {
        let lang = Locale.preferredLanguages.first ?? "en"
        if lang.hasPrefix("zh") { return labels["zh"] ?? labels["en"] ?? key }
        if lang.hasPrefix("ru") { return labels["ru"] ?? labels["en"] ?? key }
        return labels["en"] ?? labels["zh"] ?? key
    }
}

/// A196: 菜单配置仓库 —— 启动/回前台时从服务器拉取；失败则用内置默认值
final class AppTabsStore: ObservableObject {
    static let shared = AppTabsStore()
    @Published var tabs: [AppTabItem] = AppTabsStore.defaults
    private var loading = false

    static let defaults: [AppTabItem] = [
        AppTabItem(key: "shop", slot: 1, kind: "web", url: "https://like-art.com/?app=1",
                   nativeKey: nil, labels: ["zh": "商城", "en": "Shop", "ru": "Магазин"], icon: "bag"),
        AppTabItem(key: "world", slot: 2, kind: "web", url: "https://like-art.com/v6/?app=1",
                   nativeKey: nil, labels: ["zh": "玩偶世界", "en": "Doll World", "ru": "Мир кукол"], icon: "globe"),
        AppTabItem(key: "live", slot: 3, kind: "web", url: "https://like-art.com/live?app=1",
                   nativeKey: nil, labels: ["zh": "直播广场", "en": "Live", "ru": "Эфиры"], icon: "video"),
        AppTabItem(key: "profile", slot: 4, kind: "native", url: nil,
                   nativeKey: "profile", labels: ["zh": "我的", "en": "Profile", "ru": "Профиль"],
                   icon: "person.crop.circle"),
    ]

    /// 拉取配置；任何异常都保持上一次可用值（绝不出现空菜单）
    func load() {
        if loading { return }
        loading = true
        let stamp = Int(Date().timeIntervalSince1970)
        guard let u = URL(string: "https://like-art.com/api/app-tabs?t=\(stamp)") else { loading = false; return }
        var req = URLRequest(url: u)
        req.timeoutInterval = 6
        req.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        req.setValue("LikeArtApp/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { DispatchQueue.main.async { AppTabsStore.shared.loading = false } }
            guard let data = data,
                  let raw = try? JSONSerialization.jsonObject(with: data),
                  let obj = raw as? [String: Any],
                  let arr = obj["data"] as? [[String: Any]] else { return }
            var items: [AppTabItem] = []
            for a in arr {
                guard let key = a["key"] as? String, let slot = a["slot"] as? Int else { continue }
                var labels: [String: String] = [:]
                if let l = a["labels"] as? [String: Any] {
                    for (k, v) in l { labels[k] = "\(v)" }
                }
                items.append(AppTabItem(
                    key: key, slot: slot,
                    kind: (a["kind"] as? String) ?? "web",
                    url: a["url"] as? String,
                    nativeKey: a["nativeKey"] as? String,
                    labels: labels,
                    icon: (a["icon"] as? String) ?? "square"))
            }
            let sorted = items.sorted { $0.slot < $1.slot }
            // 安全闸门：至少 2 个、最多 5 个，否则视为坏配置丢弃
            guard sorted.count >= 2, sorted.count <= 5 else { return }
            DispatchQueue.main.async { AppTabsStore.shared.tabs = sorted }
        }.resume()
    }
}
