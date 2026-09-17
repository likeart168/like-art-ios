import SwiftUI

struct WorldTab: View {
    var body: some View { WebTab(url: URL(string: "https://like-art.com/v6/?app=1")!, title: tr("世界", "World", "Мир"), tab: 1) }
}
