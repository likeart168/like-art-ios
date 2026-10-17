import Foundation

/// Session-owned, so view recreation and server tab reordering retain each route.
/// Never persist account routes to disk or accept URLs outside the existing policy.
@MainActor
final class TabNavigationHistory {
    private var lastVisitedURL: [String: URL] = [:]
    private var handledDestination: [String: URL] = [:]

    func record(_ url: URL?, for tabKey: String) {
        guard let url, AppSession.allowed(url) else { return }
        lastVisitedURL[tabKey] = url
    }

    func restore(for tabKey: String, canonicalURL: URL) -> URL {
        lastVisitedURL[tabKey] ?? canonicalURL
    }

    func destination(for tabKey: String) -> URL? { handledDestination[tabKey] }

    func handled(_ url: URL, for tabKey: String) {
        guard AppSession.allowed(url) else { return }
        handledDestination[tabKey] = url
    }

    func reset() {
        lastVisitedURL.removeAll()
        handledDestination.removeAll()
    }
}
