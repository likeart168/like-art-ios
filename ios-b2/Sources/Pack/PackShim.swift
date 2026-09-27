import Foundation

/// Inject the verified public catalog into the native message transport.
enum PackShim {
    static func script(entries: [String]) -> String {
        guard let url = Bundle.main.url(forResource: "world-pack-transport", withExtension: "js"),
              let template = try? String(contentsOf: url, encoding: .utf8),
              let data = try? JSONSerialization.data(withJSONObject: entries),
              let names = String(data: data, encoding: .utf8),
              let queriesURL = Bundle.main.url(forResource: "v6-pack-queries", withExtension: "json"),
              let queries = try? String(contentsOf: queriesURL, encoding: .utf8) else { return "" }
        return template.replacingOccurrences(of: "__ENTRIES__", with: names)
            .replacingOccurrences(of: "__QUERIES__", with: queries)
    }
}
