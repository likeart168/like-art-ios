import Foundation
import WebKit
import Combine
import LocalAuthentication
import UserNotifications

struct APIFailure: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class AppSession: ObservableObject {
    static let shared = AppSession()
    @Published var token: String = UserDefaults.standard.bool(forKey: "biometric") ? "" : KeychainStore.read() ?? ""
    @Published var locked = UserDefaults.standard.bool(forKey: "biometric")
    @Published var selectedTab = 0
    @Published var destination: URL?
    @Published var revision = UUID()
    @Published var error: String?
    private let noRedirect = NoRedirect()
    private lazy var client = URLSession(configuration: .default, delegate: noRedirect, delegateQueue: nil)

    static func allowed(_ url: URL) -> Bool {
        url.scheme == "https" && ["like-art.com", "www.like-art.com"].contains(url.host?.lowercased() ?? "")
    }
    var account: String {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return "guest" }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "guest" }
        return "\(claims["role"] ?? "buyer"):\(claims["id"] ?? claims["userId"] ?? "guest")"
    }
    func open(_ url: URL) {
        guard Self.allowed(url) else { return }
        selectedTab = url.path.hasPrefix("/v6") ? 1 : 0
        destination = url
    }
    func accept(_ value: String) async {
        guard !locked else { return }
        guard value != token else { return }
        if value.isEmpty { await signOut(); return }
        let previous = token
        do {
            _ = try await request("/api/auth/me", overrideToken: value)
            guard token == previous else { return }
            // A new web login changes the credential; biometric protection must be enrolled again.
            KeychainStore.clearBiometrics()
            try KeychainStore.save(value)
            token = value
            revision = UUID()
            await PushSettings.shared.sync()
        } catch { self.error = error.localizedDescription }
    }
    func signOut() async {
        let old = token
        if !old.isEmpty { await PushSettings.shared.disableForLogout() }
        guard token == old else { return }
        KeychainStore.clear()
        KeychainStore.clearBiometrics()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        token = ""
        locked = false
        UserDefaults.standard.set(false, forKey: "biometric")
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        revision = UUID()
    }
    func unlock() async throws {
        let context = LAContext()
        guard try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: tr("解锁 Like Art", "Unlock Like Art", "Разблокировать Like Art")) else { return }
        let saved = try KeychainStore.unlockBiometrics(context: context)
        // Keep offline access usable after successful local authentication. Each server request still validates the JWT.
        token = saved
        locked = false
        revision = UUID()
    }
    func request(_ path: String, body: [String: Any]? = nil, overrideToken: String? = nil) async throws -> [String: Any] {
        guard path.hasPrefix("/api/") || path.hasPrefix("/dw-dev/api/") else { throw URLError(.badURL) }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let shared = HTTPCookieStorage.shared
        shared.cookies?.filter { $0.domain.hasSuffix("like-art.com") }.forEach { shared.deleteCookie($0) }
        cookies.filter { $0.domain == "like-art.com" || $0.domain == ".like-art.com" || $0.domain == "www.like-art.com" }.forEach { shared.setCookie($0) }
        var request = URLRequest(url: URL(string: "https://like-art.com" + path)!)
        request.timeoutInterval = 20
        let credential = overrideToken ?? token
        if !credential.isEmpty { request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LikeArtApp/1.0 iOS", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await client.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status), !json.isEmpty, json["success"] as? Bool != false else {
            throw APIFailure(status: status, message: json["message"] as? String ?? tr("请求失败，请重试或重新登录", "Request failed. Retry or sign in again.", "Ошибка запроса. Повторите или войдите снова."))
        }
        for cookie in shared.cookies ?? [] where cookie.domain.hasSuffix("like-art.com") {
            await WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie)
        }
        return json
    }
}

enum DiskCache {
    static func url(_ name: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LikeArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safe = Data(name.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(safe + ".json")
    }
    static func read(_ name: String) -> Data? { try? Data(contentsOf: url(name)) }
    static func modified(_ name: String) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url(name).path)
        return attributes?[.modificationDate] as? Date
    }
    static func write(_ data: Data, _ name: String) throws {
        try data.write(to: url(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
