#!/usr/bin/env python3
"""Protect the native half of inline/swipe playback before creating an IPA."""
import pathlib
import re


def verify(source):
    # Ignore comments so leaving the old policy commented out cannot pass CI.
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    source = re.sub(r'(?m)^\s*//.*$', '', source)
    start = source.index('func makeUIView(')
    end = source.index('func updateUIView(', start)
    factory = source[start:end]
    creation = re.search(r'let\s+view\s*=\s*(?:WKWebView|ClipsViewportWebView)\(frame:\s*\.zero,\s*configuration:\s*configuration\)', factory)
    assert creation, 'Native WebView construction must remain auditable'
    for key, value in [('allowsInlineMediaPlayback', 'true'), ('mediaTypesRequiringUserActionForPlayback', '[]')]:
        assignments = list(re.finditer(r'configuration\.' + key + r'\s*=\s*([^\n;]+)', factory))
        assert assignments and assignments[-1].group(1).split('//')[0].strip() == value, 'Clips policy missing or overridden: ' + key
        assert all(item.start() < creation.start() for item in assignments), 'Clips policy must be set before WKWebView: ' + key
        # These policies must apply to shop-to-Clips navigation as well as a direct Clips URL.
        prefix = factory[factory.index('let configuration'):assignments[-1].start()]
        assert not re.search(r'\b(if|switch|guard)\b', prefix), 'Do not condition native playback policy on the initial URL'
    assert '!url.path.hasPrefix("/v6/clips/")' in factory, 'Clips must not wait for a world asset pack'
    assert 'setAllMediaPlaybackSuspended(true' in source and 'setAllMediaPlaybackSuspended(false' in source, 'Keep background/tab media suspension'
    assert 'func dismantleUIView' in source and 'removeScriptMessageHandler' in source, 'Keep WebView cleanup'
    return True


if __name__ == '__main__':
    verify(pathlib.Path('ios-b2/Sources/Tabs/MarketplaceTab.swift').read_text())
    print('PASS Clips inline/autoplay policy before WKWebView construction; background suspension retained')
