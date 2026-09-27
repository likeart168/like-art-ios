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
    @Environment(\.dismiss) private var dismiss
    @State private var messagesVisible = false
    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                if let avatar {
                    AsyncImage(url: avatar) { image in image.resizable().scaledToFill() } placeholder: { BrandMark(size: 76) }
                        .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 23))
                } else { BrandMark(size: 76) }
                VStack(alignment: .leading, spacing: 7) {
                    Text(session.token.isEmpty ? tr("欢迎来到 Like Art", "Make art part of life", "Искусство рядом") : name)
                        .font(.system(.title2, design: .serif).weight(.semibold)).foregroundStyle(AppTheme.ink)
                    Text(tr("手作 · 收藏 · 相遇", "Create · Collect · Connect", "Творить · Собирать · Общаться"))
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                }
            }
            if session.token.isEmpty {
                Button(tr("登录，开启你的收藏故事", "Sign in to your collection", "Войти в свою коллекцию")) { session.open(URL(string: "https://like-art.com/?app=1")!); dismiss() }.buttonStyle(ArtPrimaryButton())
            } else {
                HStack(spacing: 12) {
                    metric(tr("积分", "Points", "Баллы"), value: points)
                    metric(tr("等级", "Level", "Уровень"), value: level)
                }
            }
        }.padding(.vertical, 10)
    }
    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(AppTheme.tint)
            Text(label).font(.caption).foregroundStyle(AppTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(AppTheme.soft, in: RoundedRectangle(cornerRadius: 16))
    }
    var body: some View {
        NavigationStack {
            List {
                Section { hero }.listRowBackground(AppTheme.surface).listRowSeparator(.hidden)
                Section(tr("你的灵感空间", "Your creative space", "Ваше пространство")) {
                    HStack(spacing: 8) {
                        ArtShortcut(symbol: "play.rectangle", title: tr("短视频", "Clips", "Видео")) { session.open(URL(string: "https://like-art.com/clips?app=1")!); dismiss() }
                        ArtShortcut(symbol: "plus.rectangle", title: tr("发布视频", "Share a video", "Поделиться")) { session.open(URL(string: "https://like-art.com/clips/upload?app=1")!); dismiss() }
                        ArtShortcut(symbol: "heart", title: tr("个人主页", "My space", "Моя страница")) { session.open(URL(string: "https://like-art.com/account?app=1")!); dismiss() }
                    }.padding(.vertical, 4)
                }.listRowBackground(AppTheme.surface)
                Section(tr("消息与偏好", "Stay connected", "Связь и настройки")) {
                    Button { messagesVisible = true } label: { Label(tr("通知与消息", "Notifications & messages", "Уведомления и сообщения"), systemImage: "bell.badge") }
                    Toggle(isOn: Binding(get: { push.enabled }, set: { value in Task { await push.setEnabled(value) } })) { Label(tr("推送通知", "Push notifications", "Push-уведомления"), systemImage: "bell") }.disabled(session.token.isEmpty)
                    if !push.status.isEmpty { Text(push.status).font(.footnote).foregroundStyle(AppTheme.muted) }
                    Button { offline = true } label: { Label(tr("离线内容", "Saved on this device", "Сохранённое на устройстве"), systemImage: "arrow.down.circle") }
                    if !session.token.isEmpty {
                        Button { Task { await biometric() } } label: { Label(biometricEnabled ? tr("关闭生物识别登录", "Disable biometric sign-in", "Отключить биометрию") : tr("开启生物识别登录", "Enable biometric sign-in", "Включить биометрию"), systemImage: "faceid") }
                    }
                }.listRowBackground(AppTheme.surface)
                if !session.token.isEmpty {
                    Section(tr("账户管理", "Account management", "Управление аккаунтом")) {
                        Button(tr("退出登录", "Sign out", "Выйти")) { Task { await session.signOut() } }
                        if pending == true {
                            TimelineView(.periodic(from: .now, by: 60)) { context in Text(countdown(context.date)).foregroundStyle(.red) }
                            Button(tr("撤销注销", "Cancel account deletion", "Отменить удаление")) { Task { await mutateDeletion(false) } }.disabled(busy)
                        } else if pending == false {
                            Button(tr("注销账号", "Delete account", "Удалить аккаунт"), role: .destructive) { confirm = true }.disabled(busy)
                        } else {
                            Text(tr("注销状态尚未同步", "Deletion status not synced", "Статус удаления не синхронизирован")).font(.footnote)
                            Button(tr("重试", "Retry", "Повторить")) { Task { await refresh() } }
                        }
                    }.listRowBackground(AppTheme.surface)
                }
                Section(tr("关于 Like Art", "About Like Art", "О Like Art")) {
                    Link(destination: URL(string: "https://like-art.com/privacy")!) { Label(tr("隐私政策", "Privacy policy", "Конфиденциальность"), systemImage: "hand.raised") }
                    Link(destination: URL(string: "mailto:support@like-art.com?subject=Like%20Art%20Content%20Report")!) { Label(tr("举报内容", "Report content", "Сообщить о нарушении"), systemImage: "flag") }
                    Text(tr("举报请附内容链接与原因。", "Please include the content link and reason when reporting.", "В жалобе укажите ссылку и причину.")).font(.footnote).foregroundStyle(AppTheme.muted)
                    Text("Like Art \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")").font(.caption).foregroundStyle(AppTheme.muted)
                }.listRowBackground(AppTheme.surface)
                if !status.isEmpty { Section { Text(status).font(.footnote).foregroundStyle(AppTheme.muted) }.listRowBackground(AppTheme.surface) }
            }
            .scrollContentBackground(.hidden).background(AppTheme.paper).listStyle(.insetGrouped)
            .navigationTitle(tr("我的", "My space", "Мой профиль"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("完成", "Done", "Готово")) { dismiss() } } }
            .refreshable { await refresh() }
            .task(id: session.token) { await refresh() }
            .onChange(of: session.destination) { _ in dismiss() }
            .alert(tr("注销账号", "Delete account", "Удалить аккаунт"), isPresented: $confirm) {
                Button(tr("返回", "Back", "Назад"), role: .cancel) {}
                Button(tr("确认申请注销", "Request deletion", "Запросить удаление"), role: .destructive) { Task { await mutateDeletion(true) } }
            } message: {
                Text(tr("申请后有30天冷静期，可随时撤销。到期后个人信息将匿名化；未完成的订单须先处理。", "You have a 30-day cooling-off period and may cancel at any time. Personal data is then anonymised. Open orders must be completed first.", "Период ожидания — 30 дней; запрос можно отменить. Затем личные данные обезличиваются. Сначала завершите открытые заказы."))
            }
            .sheet(isPresented: $messagesVisible) { MessagesTab().environmentObject(session) }
            .sheet(isPresented: $offline) {
                NavigationStack {
                    List {
                        Section(tr("已保存账户", "Saved account", "Сохранённый профиль")) {
                            Text(name)
                            Text(tr("积分余额：", "Points: ", "Баланс баллов: ") + points)
                            if let savedAt = DiskCache.modified("profile-" + session.account) { Text(savedAt, style: .date) }
                        }
                        Button(tr("查看已保存消息", "View saved messages", "Сохранённые сообщения")) { offline = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { messagesVisible = true } }
                        Text(tr("离线数据可能不是最新状态。", "Saved information may be out of date.", "Сохранённые данные могут быть устаревшими.")).font(.footnote).foregroundStyle(AppTheme.muted)
                    }.scrollContentBackground(.hidden).background(AppTheme.paper).navigationTitle(tr("离线内容", "Saved content", "Сохранённое"))
                        .toolbar { Button(tr("完成", "Done", "Готово")) { offline = false } }
                }
            }
        }.tint(AppTheme.tint)
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
