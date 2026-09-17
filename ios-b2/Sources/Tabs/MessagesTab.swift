import SwiftUI
import UIKit

struct MessagesTab: View {
    @EnvironmentObject var session: AppSession
    @State private var messages: [NativeMessage] = []
    @State private var status = ""
    var body: some View {
        NavigationStack {
            VStack {
                if !status.isEmpty { Text(status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal) }
                if messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell").font(.largeTitle)
                        Text(tr("暂无消息", "No messages yet", "Пока нет сообщений")).font(.headline)
                        Text(tr("登录后查看站内通知和本地推送历史。发现不当内容可前往“我的”举报；我们不允许骚扰或违法内容。", "Sign in to view notifications and saved push history. Report inappropriate content from Profile. Harassment and illegal content are not allowed.", "Войдите для просмотра уведомлений и сохранённой истории push. Сообщайте о нарушениях в профиле. Преследование и незаконный контент запрещены."))
                        if session.token.isEmpty { Button(tr("登录", "Sign in", "Войти")) { session.open(URL(string: "https://like-art.com/?app=1")!) } }
                    }.multilineTextAlignment(.center).padding().frame(maxHeight: .infinity)
                } else { MessageTable(messages: messages) }
            }
            .navigationTitle(tr("消息", "Messages", "Сообщения"))
            .toolbar { Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel(tr("刷新", "Refresh", "Обновить")) }
            .task(id: session.token) { await refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .init("LikeArtPushHistoryChanged"))) { _ in Task { await refresh() } }
        }
    }
    private func refresh() async {
        guard !session.token.isEmpty else { messages = []; status = ""; return }
        let credential = session.token
        let account = session.account
        let push = DiskCache.read("push-" + account).flatMap { try? JSONDecoder().decode([NativeMessage].self, from: $0) } ?? []
        let cached = DiskCache.read("messages-" + account).flatMap { try? JSONDecoder().decode([NativeMessage].self, from: $0) } ?? []
        messages = push + cached
        do {
            let result: [String: Any]
            do { result = try await session.request("/api/auth/notifications") }
            catch let failure as APIFailure where failure.status == 404 { result = try await session.request("/api/social/notifications") }
            guard credential == session.token else { return }
            let data = result["data"]
            let rows = (data as? [[String: Any]]) ?? ((data as? [String: Any])?["notifications"] as? [[String: Any]]) ?? (result["notifications"] as? [[String: Any]]) ?? []
            let remote = rows.enumerated().map { index, row in NativeMessage(id: "remote-\(row["id"] ?? index)", title: row["title"] as? String ?? "Like Art", body: row["message"] as? String ?? row["content"] as? String ?? row["body"] as? String ?? "", date: row["created_at"] as? String ?? "") }
            try DiskCache.write(try JSONEncoder().encode(remote), "messages-" + account)
            messages = push + remote
            status = tr("站内通知与本地推送历史", "Notifications and saved push history", "Уведомления и сохранённая история push")
        } catch {
            guard credential == session.token else { return }
            status = tr("离线缓存 · ", "Saved offline · ", "Офлайн-копия · ") + error.localizedDescription
        }
    }
}

struct MessageTable: UIViewRepresentable {
    let messages: [NativeMessage]
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UITableView {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.dataSource = context.coordinator
        table.allowsSelection = false
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 90
        return table
    }
    func updateUIView(_ table: UITableView, context: Context) { context.coordinator.messages = messages; table.reloadData() }
    final class Coordinator: NSObject, UITableViewDataSource {
        var messages: [NativeMessage] = []
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "message") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "message")
            let row = messages[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = row.title
            content.secondaryText = row.body + "\n" + row.date
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
            return cell
        }
    }
}
