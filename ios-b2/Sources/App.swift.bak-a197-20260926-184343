import SwiftUI

func tr(_ zh: String, _ en: String, _ ru: String) -> String {
    let language = Locale.preferredLanguages.first ?? "en"
    return language.hasPrefix("zh") ? zh : language.hasPrefix("ru") ? ru : en
}

@main
struct LikeArtApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var delegate
    @StateObject private var session = AppSession.shared
    @StateObject private var tabs = AppTabsStore.shared
    @Environment(\.scenePhase) private var scenePhase

    /// A196: 按配置渲染每个 Tab（web → WebView；native → 原生页）
    @ViewBuilder
    private func tabContent(_ item: AppTabItem, index: Int) -> some View {
        switch item.nativeKey ?? "" {
        case "messages":
            MessagesTab()
        case "profile":
            ProfileTab()
        default:
            if let s = item.url, let u = URL(string: s) {
                WebTab(url: u, title: item.labelText(), tab: index)
            } else {
                WebTab(url: URL(string: "https://like-art.com/?app=1")!, title: item.labelText(), tab: index)
            }
        }
    }
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
                    // A196: 底部菜单由服务端配置驱动（/api/app-tabs），可随时改、可隐藏
                    TabView(selection: $session.selectedTab) {
                        ForEach(Array(tabs.tabs.enumerated()), id: \.element.key) { idx, item in
                            tabContent(item, index: idx)
                                .tabItem { Label(item.labelText(), systemImage: item.icon) }
                                .tag(idx)
                        }
                    }
                    .onAppear { AppTabsStore.shared.load() }
                    .onChange(of: scenePhase) { phase in
                        if phase == .active { AppTabsStore.shared.load() }
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
