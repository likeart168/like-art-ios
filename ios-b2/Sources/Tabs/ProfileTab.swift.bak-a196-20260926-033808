import SwiftUI
import LocalAuthentication

struct ProfileTab: View {
    @EnvironmentObject var session: AppSession
    @ObservedObject private var push = PushSettings.shared
    @State private var name = "Like Art"
    @State private var points = "—"
    @State private var level = "—"
    @AppStorage("biometric") private var biometricEnabled = false
    @State private var avatar: URL?
    @State private var pending: Bool?
    @State private var scheduled: Date?
    @State private var scheduledText = ""
    @State private var status = ""
    @State private var busy = false
    @State private var confirm = false
    @State private var offline = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        AsyncImage(url: avatar) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.crop.circle").resizable().scaledToFit() }
                            .frame(width: 48, height: 48).clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(name).font(.headline)
                            Text(tr("等级：", "Level: ", "Уровень: ") + level).font(.subheadline)
                            Text(tr("积分余额：", "Points: ", "Баланс баллов: ") + points)
                        }
                    }
                    if session.token.isEmpty {
                        Button(tr("登录账户", "Sign in", "Войти")) { session.open(URL(string: "https://like-art.com/?app=1")!) }
                    } else {
                        Button(biometricEnabled ? tr("关闭生物识别登录", "Disable biometric sign-in", "Отключить биометрию") : tr("开启生物识别登录", "Enable biometric sign-in", "Включить вход по биометрии")) { Task { await biometric() } }
                        Button(tr("退出登录", "Sign out", "Выйти")) { Task { await session.signOut() } }
                    }
                }
                Section {
                    Toggle(tr("推送通知", "Push notifications", "Push-уведомления"), isOn: Binding(get: { push.enabled }, set: { value in Task { await push.setEnabled(value) } }))
                        .disabled(session.token.isEmpty)
                    if !push.status.isEmpty { Text(push.status).font(.footnote) }
                    Button(tr("离线内容", "Offline content", "Офлайн-данные")) { offline = true }
                }
                if !session.token.isEmpty {
                    Section(tr("账户管理", "Account management", "Управление аккаунтом")) {
                        if pending == true {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                Text(countdown(context.date)).foregroundStyle(.red)
                            }
                            Button(tr("撤销注销", "Cancel account deletion", "Отменить удаление")) { Task { await mutateDeletion(false) } }.disabled(busy)
                        } else if pending == false {
                            Button(tr("注销账号", "Delete account", "Удалить аккаунт"), role: .destructive) { confirm = true }.disabled(busy)
                        } else {
                            Text(tr("注销状态尚未同步", "Deletion status not synced", "Статус удаления не синхронизирован"))
                            Button(tr("重试", "Retry", "Повторить")) { Task { await refresh() } }
                        }
                    }
                }
                Section(tr("关于", "About", "О приложении")) {
                    Text("Like Art \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                    Link(tr("举报内容", "Report content", "Сообщить о нарушении"), destination: URL(string: "mailto:support@like-art.com?subject=Like%20Art%20Content%20Report")!)
                    Text(tr("请附上内容链接及原因。禁止骚扰和违法内容，社区页面将提供举报与屏蔽功能。", "Include the content link and reason. Harassment and illegal content are prohibited. Community reporting and blocking controls are being added.", "Укажите ссылку и причину. Преследование и незаконный контент запрещены. Функции жалоб и блокировки в сообществе добавляются.")).font(.footnote)
                    Link(tr("隐私政策", "Privacy policy", "Политика конфиденциальности"), destination: URL(string: "https://like-art.com/privacy")!)
                }
                if !status.isEmpty { Section { Text(status).font(.footnote) } }
            }
            .navigationTitle(tr("我的", "Profile", "Профиль"))
            .refreshable { await refresh() }
            .task(id: session.token) { await refresh() }
            .alert(tr("注销账号", "Delete account", "Удалить аккаунт"), isPresented: $confirm) {
                Button(tr("返回", "Back", "Назад"), role: .cancel) {}
                Button(tr("确认申请注销", "Request deletion", "Запросить удаление"), role: .destructive) { Task { await mutateDeletion(true) } }
            } message: {
                Text(tr("申请后有30天冷静期，可随时撤销。到期后个人信息将匿名化；未完成的订单须先处理。", "You have a 30-day cooling-off period and may cancel at any time. Personal data is then anonymised. Open orders must be completed first.", "Период ожидания — 30 дней; запрос можно отменить. Затем личные данные обезличиваются. Сначала завершите открытые заказы."))
            }
            .sheet(isPresented: $offline) {
                NavigationStack {
                    List {
                        Text(tr("已保存账户", "Saved account", "Сохранённый профиль"))
                        Text(name)
                        Text(tr("积分余额：", "Points: ", "Баланс баллов: ") + points)
                        if let savedAt = DiskCache.modified("profile-" + session.account) {
                            Text(savedAt, style: .date)
                        }
                        Button(tr("查看已保存消息", "View saved messages", "Сохранённые сообщения")) { offline = false; session.selectedTab = 2 }
                        Text(tr("网页优先使用系统缓存；账户和消息保存在本机。离线数据可能不是最新状态。", "Web pages use system caching. Account details and messages are saved on this device and may be out of date.", "Веб-страницы используют системный кэш. Профиль и сообщения сохраняются на устройстве и могут быть устаревшими."))
                    }.navigationTitle(tr("离线内容", "Offline content", "Офлайн-данные"))
                    .toolbar { Button(tr("完成", "Done", "Готово")) { offline = false } }
                }
            }
        }
    }
    private func countdown(_ now: Date) -> String {
        guard let scheduled else { return tr("计划注销时间：", "Deletion scheduled: ", "Удаление запланировано: ") + scheduledText }
        let days = max(0, Int(ceil(scheduled.timeIntervalSince(now) / 86400)))
        return tr("账号将在 \(days) 天后注销", "Account deletion in \(days) days", "Удаление аккаунта через \(days) дн.")
    }
    private func readDeletion(_ data: [String: Any]) {
        let value = data["data"] as? [String: Any] ?? data
        pending = value["pending"] as? Bool
        scheduledText = value["scheduled_at"] as? String ?? ""
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        scheduled = format.date(from: scheduledText) ?? ISO8601DateFormatter().date(from: scheduledText)
    }
    private func refresh() async {
        name = "Like Art"; points = "—"; level = "—"; avatar = nil; pending = nil; status = ""
        guard !session.token.isEmpty else { return }
        let credential = session.token
        let key = "profile-" + session.account
        if let data = DiskCache.read(key), let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            name = saved["name"] ?? name; points = saved["points"] ?? points; level = saved["level"] ?? level
        }
        do {
            let result = try await session.request("/api/auth/me")
            guard credential == session.token else { return }
            let data = result["data"] as? [String: Any] ?? result
            let user = data["user"] as? [String: Any] ?? data
            name = user["nickname"] as? String ?? user["name"] as? String ?? user["username"] as? String ?? "Like Art"
            level = "\(user["level"] ?? user["member_level"] ?? "—")"
            avatar = (user["avatar_url"] as? String ?? user["avatar_oss_url"] as? String).flatMap(URL.init(string:))
            try DiskCache.write(try JSONEncoder().encode(["name": name, "points": points, "level": level]), key)
            let balance = try await session.request("/dw-dev/api/points/balance")
            guard credential == session.token else { return }
            let value = balance["data"] as? [String: Any] ?? balance
            points = "\(value["balance"] ?? "—")"
            try DiskCache.write(try JSONEncoder().encode(["name": name, "points": points, "level": level]), key)
        } catch { if credential == session.token { status = error.localizedDescription } }
        // Deletion status must remain accessible even if points service is unavailable.
        do {
            let deletion = try await session.request("/api/auth/deletion-status")
            guard credential == session.token else { return }
            readDeletion(deletion)
        } catch { if credential == session.token { status = error.localizedDescription } }
    }
    private func mutateDeletion(_ request: Bool) async {
        busy = true
        defer { busy = false }
        let credential = session.token
        do {
            _ = try await session.request("/api/auth/" + (request ? "request-deletion" : "cancel-deletion"), body: [:])
            guard credential == session.token else { return }
            let result = try await session.request("/api/auth/deletion-status")
            guard credential == session.token else { return }
            readDeletion(result)
            status = tr("注销状态已更新", "Deletion status updated", "Статус удаления обновлён")
        } catch { if credential == session.token { status = error.localizedDescription } }
    }
    private func biometric() async {
        let context = LAContext()
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: tr("验证您的 Like Art 账户", "Verify your Like Art account", "Подтвердите аккаунт Like Art")) else { return }
            let token = session.token
            guard !token.isEmpty else { return }
            if biometricEnabled {
                try KeychainStore.save(token)
                KeychainStore.clearBiometrics()
                status = tr("已关闭生物识别登录", "Biometric sign-in disabled", "Вход по биометрии отключён")
                return
            }
            _ = try await session.request("/api/auth/me", overrideToken: token)
            try KeychainStore.enrollBiometrics(token)
            status = tr("已开启，下次启动时使用生物识别解锁。", "Enabled. Unlock with biometrics on the next launch.", "Включено. При следующем запуске используйте биометрию.")
        } catch { status = error.localizedDescription }
    }
}
