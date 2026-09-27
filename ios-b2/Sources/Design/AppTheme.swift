import SwiftUI
import UIKit

// Shared with the website: sage #87B360, warm paper #FBF7F3.
enum AppTheme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
    static let paperUI = adaptive(0xFBF7F3, 0x182019)
    static let surfaceUI = adaptive(0xFFFFFF, 0x253027)
    static let inkUI = adaptive(0x2B3528, 0xF4F4EC)
    static let mutedUI = adaptive(0x706860, 0xC1C6B8)
    static let tintUI = adaptive(0x416533, 0xB7D795)
    static let paper = Color(paperUI)
    static let surface = Color(surfaceUI)
    static let ink = Color(inkUI)
    static let muted = Color(mutedUI)
    static let tint = Color(tintUI)
    static let sage = Color(red: 135/255, green: 179/255, blue: 96/255)
    static let soft = Color(adaptive(0xEDF3E4, 0x303F2C))
    static func configure() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = paperUI
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: inkUI]
        navigation.largeTitleTextAttributes = [.foregroundColor: inkUI]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().tintColor = tintUI
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = paperUI
        tab.shadowColor = adaptive(0xE8E2D8, 0x394334)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = mutedUI
            item.normal.titleTextAttributes = [.foregroundColor: mutedUI]
            item.selected.iconColor = tintUI
            item.selected.titleTextAttributes = [.foregroundColor: tintUI]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITableView.appearance().backgroundColor = paperUI
    }
}

struct BrandMark: View {
    var size: CGFloat = 76
    var body: some View {
        Image("BrandMark").resizable().scaledToFit()
            .frame(width: size, height: size).background(.white)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ArtPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 16)
            .foregroundStyle(Color(red: 30/255, green: 47/255, blue: 21/255))
            .background(AppTheme.sage.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ArtEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.tint).frame(width: 84, height: 84)
                .background(AppTheme.soft, in: RoundedRectangle(cornerRadius: 28))
            Text(title).font(.system(.title2, design: .serif).weight(.semibold)).foregroundStyle(AppTheme.ink)
            Text(detail).font(.subheadline).foregroundStyle(AppTheme.muted).lineSpacing(5)
        }.multilineTextAlignment(.center).padding(24).frame(maxWidth: 440)
    }
}

struct ArtShortcut: View {
    let symbol: String
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(AppTheme.tint)
                Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(AppTheme.ink)
            }.frame(maxWidth: .infinity, minHeight: 80).padding(8)
                .background(AppTheme.soft, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}
