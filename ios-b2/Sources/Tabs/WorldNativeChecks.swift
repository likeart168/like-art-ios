#if DEBUG
import Foundation

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
    let state = WebState(), initial = state.reload
    state.retry()
    checks["healthyPageDoesNotRetry"] = state.retryAttempts == 0 && state.reload == initial
    state.failed = true
    state.retry(); state.retry()
    checks["doubleTapCoalescedWithDelay"] = state.retryAttempts == 1 && state.retryPending && state.reload == initial
    try? await Task.sleep(nanoseconds:1_200_000_000)
    checks["firstRetryExecutedOnce"] = state.retryAttempts == 1 && !state.retryPending && state.reload != initial
    let second = state.reload
    state.retry(); state.cancelRetry()
    try? await Task.sleep(nanoseconds:2_200_000_000)
    checks["cancelPreventsReload"] = state.reload == second && !state.retryPending
    state.retry(); state.retry()
    checks["thirdAttemptBudget"] = state.retryAttempts == 3
    state.cancelRetry(); state.retry()
    checks["fourthRetryBlocked"] = !state.retryPending && state.retryAttempts == 3 && state.reload == second
    let record: [String:Any] = ["pass": checks.values.allSatisfy{$0}, "checks": checks]
    if let data = try? JSONSerialization.data(withJSONObject: record, options:[.prettyPrinted,.sortedKeys]),
       let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first {
        try? data.write(to:directory.appendingPathComponent("world-native-checks-20.json"),options:.atomic)
    }
}
#endif
