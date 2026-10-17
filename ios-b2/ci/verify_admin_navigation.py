#!/usr/bin/env python3
"""Linux source guards; behavioral WKWebView checks run in DEBUG on iOS."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
session = (root / 'Sources/Auth/AppSession.swift').read_text()
market = (root / 'Sources/Tabs/MarketplaceTab.swift').read_text()
history = (root / 'Sources/Tabs/TabNavigationHistory.swift').read_text()
app = (root / 'Sources/App.swift').read_text()
checks = (root / 'Sources/Tabs/WorldNativeChecks.swift').read_text()

accept = session.split('func accept(', 1)[1].split('func signOut()', 1)[0]
logout = session.split('func signOut()', 1)[1].split('func unlock()', 1)[0]
unlock = session.split('func unlock()', 1)[1].split('func request(', 1)[0]
assert 'token = value' in accept and 'revision =' not in accept
assert 'revision = UUID()' in logout and 'revision = UUID()' in unlock
assert 'tabNavigation.reset()' in logout and 'destination = nil' in logout
assert '.id(session.revision)' in market
assert 'url.scheme == "https" && ["like-art.com", "www.like-art.com"].contains(url.host?.lowercased() ?? "")' in session
print('PASS login preserves WebView identity; logout/unlock rebuild and URL policy retained')

assert 'let tabNavigation = TabNavigationHistory()' in session
assert app.count('tabKey: item.key') == 2
assert 'lastVisitedURL[tabKey] ?? canonicalURL' in history
assert 'guard let url, AppSession.allowed(url) else { return }' in history
assert 'UserDefaults' not in history and 'DiskCache' not in history
assert 'view.observe(\\.url' in market and 'coordinator?.record(current)' in market
assert 'guard !disposed, revision == session.revision else { return }' in market
assert 'coordinator.disposed = true' in market
assert market.count('record(webView.url)') == 2  # commit + finish, plus URL KVO for SPA
assert 'session.tabNavigation.restore(for: tabKey, canonicalURL: url)' in market
assert 'view.url ?? session.tabNavigation.restore' in market
assert 'destination = session.tabNavigation.destination(for: tabKey)' in market
assert market.count('context.coordinator.markDestinationHandled()') == 2
print('PASS stable tab keys, in-memory route restore, stale callback guard and consumed deep links')

assert market.count('context.coordinator.syncSessionScript(session.token, controller:') == 2
assert 'controller.userScripts.map { $0 === previous ? replacement : $0 }' in market
assert 'scripts.forEach { controller.addUserScript($0) }' in market
assert 'initialNavigation.request(destination)' in market
assert 'initialNavigation.finish(defaultURL: target)' in market
assert 'initialNavigation.cancel()' in market
assert '.onChange(of: scenePhase)' in app and 'AppTabsStore.shared.load()' in app
print('PASS token script replacement preserves other scripts, pack gate and config reload remain wired')

required = [
    'tabRebuildRestoresLastVisitedNotCanonical', 'rebuildDoesNotReplayOldLoginLink',
    'queuedDeepLinkNotConsumedBeforeLoad', 'disposedObservationCannotOverwriteRoute',
    'tabKeysIsolateWorldAndAdmin', 'newTabUsesHotUpdatedCanonical',
    'unsafeOrEmptyURLCannotReplaceAdminRoute', 'newExplicitDestinationStillWins',
    'tokenRefreshPreservesPackAndReplacesOnlySessionScript',
    'logoutResetRejectsOldAccountObservation',
]
assert all(f'checks["{name}"]' in checks for name in required)
assert 'IOS_SHELL_NAV_CHECKS' in app
print(f'PASS {len(required)} native regression checks and standalone DEBUG launch switch present (not executed here)')
