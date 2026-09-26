import SwiftUI

func tr(_ zh: String, _ en: String, _ ru: String) -> String {
    let language = Locale.preferredLanguages.first ?? "en"
    return language.hasPrefix("zh") ? zh : language.hasPrefix("ru") ? ru : en
}

@main
struct LikeArtApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var delegate
    @StateObject private var session = AppSession.shared
    var body: some Scene {
        WindowGroup {
            Group {
                if session.locked {
                    VStack(spacing: 24) {
                        Image(systemName: "faceid").font(.largeTitle)
                        Text("Like Art").font(.largeTitle)
                        Button(tr("生物识别登录", "Sign in with biometrics", "Войти по биометрии")) {
                            Task { do { try await session.unlock() } catch { session.error = error.localizedDescription } }
                        }
                        Button(tr("使用其他账号", "Use another account", "Другой аккаунт")) { Task { await session.signOut() } }
                        if let error = session.error { Text(error).font(.footnote).multilineTextAlignment(.center) }
                    }.padding()
                } else {
                    TabView(selection: $session.selectedTab) {
                MarketplaceTab().tabItem { Label(tr("商城", "Shop", "Магазин"), systemImage: "bag") }.tag(0)
                WorldTab().tabItem { Label(tr("世界", "World", "Мир"), systemImage: "globe") }.tag(1)
                MessagesTab().tabItem { Label(tr("消息", "Messages", "Сообщения"), systemImage: "bell") }.tag(2)
                ProfileTab().tabItem { Label(tr("我的", "Profile", "Профиль"), systemImage: "person.crop.circle") }.tag(3)
                    }
                }
            }
            .environmentObject(session)
            .onOpenURL { session.open($0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { session.open(url) }
            }
        }
    }
}
