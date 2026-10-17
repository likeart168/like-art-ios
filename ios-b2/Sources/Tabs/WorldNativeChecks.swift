#if DEBUG
import Foundation
import WebKit

@MainActor
func worldEntryNativeChecks20() async {
    var checks: [String: Bool] = [:]
    let session = AppSession(), world = URL(string: "https://like-art.com/v6/?app=1")!
    session.open(world)
    checks["worldLinkTargetsWorld"] = session.destinationTab == session.tabIndex(for:"world")
    session.selectedTab = session.tabIndex(for:"shop")
    checks["switchShopDoesNotRetargetWorldLink"] = session.destinationTab != session.selectedTab && session.destination == world
    session.open(URL(string:"https://untrusted.example/v6/")!)
    checks["untrustedLinkRejected"] = session.destination == world
    session.open(URL(string:"https://like-art.com/clips?app=1")!)
    checks["clipsTargetsShop"] = session.destinationTab == session.tabIndex(for:"shop")
    let canonical = URL(string: "https://like-art.com/?app=1")!
    let adminLogin = URL(string: "https://like-art.com/admin/login")!
    let dashboard = URL(string: "https://like-art.com/admin/platform/dashboard")!
    let adminPage = URL(string: "https://like-art.com/admin/platform/users?page=2#current")!
    let originalTab = WebContent.Coordinator(state: WebState(), session: session, tabKey: "shop")
    originalTab.handle(adminLogin)
    checks["queuedDeepLinkNotConsumedBeforeLoad"] = session.tabNavigation.destination(for: "shop") == nil
    originalTab.markDestinationHandled()
    originalTab.record(adminLogin)
    originalTab.record(dashboard)
    originalTab.disposed = true
    let rebuiltTab = WebContent.Coordinator(state: WebState(), session: session, tabKey: "shop")
    let restored = session.tabNavigation.restore(for: "shop", canonicalURL: canonical)
    checks["tabRebuildRestoresLastVisitedNotCanonical"] = rebuiltTab.initialNavigation.finish(defaultURL: restored) == dashboard && restored != canonical
    checks["rebuildDoesNotReplayOldLoginLink"] = rebuiltTab.destination == adminLogin
    rebuiltTab.record(adminPage)
    originalTab.record(adminLogin)
    checks["disposedObservationCannotOverwriteRoute"] = session.tabNavigation.restore(for: "shop", canonicalURL: canonical) == adminPage
    session.tabNavigation.record(world, for: "world")
    checks["tabKeysIsolateWorldAndAdmin"] = session.tabNavigation.restore(for: "world", canonicalURL: canonical) == world && session.tabNavigation.restore(for: "shop", canonicalURL: world) == adminPage
    checks["newTabUsesHotUpdatedCanonical"] = session.tabNavigation.restore(for: "new-server-tab", canonicalURL: world) == world
    for untrusted in ["https://untrusted.example/admin", "http://like-art.com/admin", "likeartpack://local/v6/index.html", "about:blank"] {
        session.tabNavigation.record(URL(string: untrusted), for: "shop")
    }
    session.tabNavigation.record(nil, for: "shop")
    checks["unsafeOrEmptyURLCannotReplaceAdminRoute"] = session.tabNavigation.restore(for: "shop", canonicalURL: canonical) == adminPage
    let explicitLink = URL(string: "https://like-art.com/clips?app=1")!
    checks["newExplicitDestinationStillWins"] = rebuiltTab.initialNavigation.request(explicitLink) == explicitLink
    let scripts = WKUserContentController()
    let packScript = WKUserScript(source: "/* pack sentinel */", injectionTime: .atDocumentStart, forMainFrameOnly: false)
    scripts.addUserScript(packScript)
    rebuiltTab.syncSessionScript("old", controller: scripts)
    rebuiltTab.syncSessionScript("new", controller: scripts)
    rebuiltTab.syncSessionScript("new", controller: scripts)
    checks["tokenRefreshPreservesPackAndReplacesOnlySessionScript"] = scripts.userScripts.count == 2 && scripts.userScripts[0].source == packScript.source && scripts.userScripts[1].source == JSBridge.script(token: "new")
    session.tabNavigation.reset()
    session.revision = UUID()
    rebuiltTab.record(adminPage)
    checks["logoutResetRejectsOldAccountObservation"] = session.tabNavigation.restore(for: "shop", canonicalURL: canonical) == canonical && session.tabNavigation.destination(for: "shop") == nil
    let navigation = InitialWebNavigation()
    checks["deepLinkWaitsForPack"] = navigation.request(world) == nil
    let newer = URL(string:"https://like-art.com/v6/?app=1&entry=latest")!
    checks["latestPendingLinkWins"] = navigation.request(newer) == nil && navigation.finish(defaultURL:world) == newer
    checks["latePackOrTimeoutCannotReload"] = navigation.finish(defaultURL:world) == nil
    checks["subsequentNavigationRemainsAvailable"] = navigation.request(world) == world
    let cancelled = InitialWebNavigation()
    _ = cancelled.request(world); cancelled.cancel()
    checks["disposedViewCannotNavigateLate"] = cancelled.finish(defaultURL:world) == nil && cancelled.request(world) == nil
    let retryDefaults = UserDefaults(suiteName: "WorldNativeChecks20")!
    retryDefaults.removePersistentDomain(forName: "WorldNativeChecks20")
    let state = WebState(tabKey: "checks", defaults: retryDefaults), initial = state.reload
    state.retry()
    checks["healthyPageDoesNotRetry"] = state.retryAttempts == 0 && state.reload == initial
    state.failed = true
    state.retry(); state.retry()
    checks["doubleTapCoalescedWithDelay"] = state.retryAttempts == 1 && state.retryPending && state.reload == initial
    let stored = retryDefaults.dictionary(forKey: "LikeArt.navigationRetry.v1.checks")
    checks["retryCountPersistsBeforeNavigation"] = state.retryPending && (stored?["attempts"] as? Int) == 1
    state.cancelRetry()
    retryDefaults.set(["attempts": 2, "lastRetryAt": Date().timeIntervalSince1970], forKey: "LikeArt.navigationRetry.v1.checks")
    let exhausted = WebState(tabKey: "checks", defaults: retryDefaults)
    exhausted.failed = true; exhausted.retry()
    checks["twoRetryBudget"] = exhausted.retryAttempts == 2 && !exhausted.retryPending
    let record: [String:Any] = ["pass": checks.values.allSatisfy{$0}, "checks": checks]
    if let data = try? JSONSerialization.data(withJSONObject: record, options:[.prettyPrinted,.sortedKeys]),
       let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first {
        try? data.write(to:directory.appendingPathComponent("world-native-checks-20.json"),options:.atomic)
    }
}
#endif
