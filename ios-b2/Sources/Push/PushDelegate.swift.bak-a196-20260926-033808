import UIKit
import UserNotifications
import Combine

struct NativeMessage: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let date: String
}

@MainActor
final class PushSettings: ObservableObject {
    static let shared = PushSettings()
    @Published var enabled = UserDefaults.standard.bool(forKey: "pushEnabled")
    @Published var status = ""
    func setEnabled(_ value: Bool) async {
        if value {
            do {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {
                    status = tr("请在系统设置中允许通知", "Allow notifications in Settings.", "Разрешите уведомления в настройках."); return
                }
                enabled = true
                UserDefaults.standard.set(true, forKey: "pushEnabled")
                UIApplication.shared.registerForRemoteNotifications()
                await sync()
            } catch { status = error.localizedDescription }
        } else {
            enabled = false
            UserDefaults.standard.set(false, forKey: "pushEnabled")
            await sync()
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }
    func disableForLogout() async {
        enabled = false
        UserDefaults.standard.set(false, forKey: "pushEnabled")
        await sync()
        UIApplication.shared.unregisterForRemoteNotifications()
    }
    func sync() async {
        guard let deviceToken = UserDefaults.standard.string(forKey: "apnsToken"), !AppSession.shared.token.isEmpty else { return }
        do {
            _ = try await AppSession.shared.request("/api/auth/push-register", body: ["token": deviceToken, "platform": "ios", "enabled": enabled])
            status = tr("通知偏好已同步", "Notification preference saved.", "Настройки уведомлений сохранены.")
        } catch { status = error.localizedDescription }
    }
}

@MainActor
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if PushSettings.shared.enabled { application.registerForRemoteNotifications() }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserDefaults.standard.set(deviceToken.map { String(format: "%02x", $0) }.joined(), forKey: "apnsToken")
        Task { await PushSettings.shared.sync() }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushSettings.shared.status = tr("推送注册尚不可用，请稍后重试。", "Push registration is unavailable. Try again later.", "Регистрация push пока недоступна. Повторите позже.")
    }
    private func save(_ notification: UNNotification) {
        guard !AppSession.shared.token.isEmpty else { return }
        let key = "push-" + AppSession.shared.account
        var items = DiskCache.read(key).flatMap { try? JSONDecoder().decode([NativeMessage].self, from: $0) } ?? []
        let content = notification.request.content
        let row = NativeMessage(id: notification.request.identifier, title: content.title, body: content.body, date: ISO8601DateFormatter().string(from: notification.date))
        items.removeAll { $0.id == row.id }
        items.insert(row, at: 0)
        do { try DiskCache.write(try JSONEncoder().encode(Array(items.prefix(200))), key) }
        catch { PushSettings.shared.status = error.localizedDescription }
        NotificationCenter.default.post(name: .init("LikeArtPushHistoryChanged"), object: nil)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            save(notification)
            completionHandler(PushSettings.shared.enabled ? [.banner, .sound, .list] : [])
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            save(response.notification)
            AppSession.shared.selectedTab = 2
            completionHandler()
        }
    }
}
