#!/usr/bin/env python3
"""Headless Chromium checks for the iOS auction entry-point script.

This intentionally uses the JavaScript extracted from JSBridge.swift so the
functional and performance checks exercise the shipped WebKit payload.
"""

from __future__ import annotations

import http.server
import json
import os
import re
import socket
import subprocess
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

import websocket


ROOT = Path(__file__).resolve().parents[2]
BRIDGE = ROOT / "ios-b2/Sources/Bridge/JSBridge.swift"


LEGACY_JS = r"""
(() => {
  if (!['like-art.com','www.like-art.com'].includes(location.hostname)) return;
  const RE_TEXT = /拍卖|竞拍|喜欢就出价|出价|auction|аукцион|\bbid(?:s|ding)?\b|オークション|入札|경매|입찰/i;
  const isAuctionPath = (url) => {
    try { return /\/(?:auctions|auction-permissions)/i.test(decodeURIComponent(new URL(url, location.href).pathname)); }
    catch (_) { return false; }
  };
  function killNode() {
    for (const a of document.querySelectorAll('a[href^="/auctions"],a[href^="/account/auctions"]')) a.remove();
    for (const a of document.querySelectorAll('a[href]')) {
      if (isAuctionPath(a.href)) a.style.setProperty('display', 'none', 'important');
    }
    if (!document.body) return;
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode, parent = node.parentElement;
      if (!parent || parent.closest('script,style,textarea') || !RE_TEXT.test(node.textContent || '')) continue;
      const target = parent.closest('a,button,[role="button"],[role="link"],[onclick],.cursor-pointer') || parent;
      target.style.setProperty('display', 'none', 'important');
    }
  }
  new MutationObserver(killNode).observe(document, {
    childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['href']
  });
  killNode();
})();
"""


def shipped_js() -> str:
    match = re.search(r'static let auctionKillJS = #"""\n(.*?)\n"""#', BRIDGE.read_text(), re.S)
    if not match:
        raise RuntimeError(f"could not extract auctionKillJS from {BRIDGE}")
    return match.group(1)


def instrument(js: str) -> str:
    """Add test-only counters without changing the production source."""
    marker = "  function killNode() {\n"
    if marker not in js:
        raise RuntimeError("new script killNode marker missing")
    js = js.replace(marker, marker + "    window.__auctionMetrics.calls++;\n    const __started = performance.now();\n", 1)
    marker = "    for (const node of nodes) inspectNode(node);\n  }"
    if marker in js:
        return js.replace(marker, marker[:-3] + "    window.__auctionMetrics.time += performance.now() - __started;\n  }", 1)
    marker = "    }\n  }\n  new MutationObserver(killNode).observe"
    if marker not in js:
        raise RuntimeError("killNode end marker missing")
    return js.replace(marker, "    }\n    window.__auctionMetrics.time += performance.now() - __started;\n  }\n  new MutationObserver(killNode).observe", 1)


class Page(http.server.BaseHTTPRequestHandler):
    body = b""

    def do_GET(self):  # noqa: N802
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(self.body)))
        self.end_headers()
        self.wfile.write(self.body)

    def log_message(self, *_args):
        pass


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


class Browser:
    def __init__(self, html: str, path: str = "/"):
        Page.body = html.encode()
        self.http = http.server.ThreadingHTTPServer(("0.0.0.0", free_port()), Page)
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True)
        self.thread.start()
        self.port = free_port()
        # The HTTP server picks its own port; use the actual bound port.
        self.port = int(self.http.server_address[1])
        self.cdp_port = free_port()
        self.profile = tempfile.mkdtemp(prefix="auction-kill-chrome-")
        chrome_binary = "/opt/google/chrome/chrome" if os.path.exists("/opt/google/chrome/chrome") else "chromium"
        self.chrome = subprocess.Popen([
            chrome_binary, "--headless=new", "--no-sandbox", "--disable-gpu", "--disable-extensions",
            f"--user-data-dir={self.profile}", f"--remote-debugging-port={self.cdp_port}",
            "--remote-allow-origins=*",
            "--host-resolver-rules=MAP like-art.com 127.0.0.1",
            "about:blank",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        target = None
        for _ in range(300):
            try:
                targets = json.load(urllib.request.urlopen(f"http://127.0.0.1:{self.cdp_port}/json/list"))
                target = next((item for item in targets if item.get("type") == "page"), None)
                if target:
                    break
            except Exception:
                time.sleep(0.05)
        if not target:
            self.close()
            raise RuntimeError("Chromium CDP target did not start")
        self.ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=30)
        self.seq = 0
        self.command("Page.navigate", {"url": f"http://like-art.com:{self.port}{path}"})
        time.sleep(0.4)

    def command(self, method: str, params=None):
        self.seq += 1
        self.ws.send(json.dumps({"id": self.seq, "method": method, "params": params or {}}))
        while True:
            response = json.loads(self.ws.recv())
            if response.get("id") == self.seq:
                if "error" in response:
                    raise RuntimeError(response["error"])
                return response.get("result", {})

    def evaluate(self, expression: str):
        self.seq += 1
        self.ws.send(json.dumps({
            "id": self.seq, "method": "Runtime.evaluate",
            "params": {"expression": expression, "returnByValue": True, "awaitPromise": True},
        }))
        while True:
            response = json.loads(self.ws.recv())
            if response.get("id") == self.seq:
                if "exceptionDetails" in response["result"]:
                    raise RuntimeError(response["result"]["exceptionDetails"])
                return response["result"].get("result", {}).get("value")

    def close(self):
        try:
            if hasattr(self, "ws"):
                self.ws.close()
        finally:
            if hasattr(self, "chrome"):
                self.chrome.terminate()
                try:
                    self.chrome.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.chrome.kill()
            if hasattr(self, "http"):
                self.http.shutdown()

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


def base_html() -> str:
    filler = "".join(f'<span>scene label {i}</span>' for i in range(4000))
    return f"""<!doctype html><html><body>
      <a id="auction" href="/auctions/123">auction link</a>
      <button id="bid">出价</button><button id="normal">Normal</button>
      <div id="churn">frame 0</div><div id="filler">{filler}</div>
    </body></html>"""


def run_functional(js: str):
    with Browser(base_html()) as browser:
        browser.evaluate("window.__auctionMetrics={calls:0,time:0};")
        browser.evaluate(js)
        time.sleep(0.4)
        initial = browser.evaluate("({auction:getComputedStyle(document.querySelector('#auction')).display,bid:getComputedStyle(document.querySelector('#bid')).display,normal:getComputedStyle(document.querySelector('#normal')).display})")
        browser.evaluate("document.body.insertAdjacentHTML('beforeend','<div id=dynamic><a id=dynAuction href=/account/auctions/9>auction</a><button id=dynBid>竞拍</button></div>');")
        time.sleep(0.4)
        dynamic = browser.evaluate("({auction:getComputedStyle(document.querySelector('#dynAuction')).display,bid:getComputedStyle(document.querySelector('#dynBid')).display})")
    assert initial == {"auction": "none", "bid": "none", "normal": "inline-block"}, initial
    assert dynamic == {"auction": "none", "bid": "none"}, dynamic
    return initial, dynamic


def run_v6(js: str):
    with Browser("<!doctype html><html><body><button id=world>出价</button></body></html>", "/v6/game.html") as browser:
        browser.evaluate(js)
        time.sleep(0.4)
        result = browser.evaluate("getComputedStyle(document.querySelector('#world')).display")
    assert result != "none", result
    return result


def run_perf(js: str, duration: float = 10.0):
    instrumented = instrument(js)
    with Browser(base_html()) as browser:
        browser.evaluate("window.__auctionMetrics={calls:0,time:0};")
        browser.evaluate(instrumented)
        browser.evaluate("(() => { const n=document.querySelector('#churn'); let i=0; window.__stop=setInterval(() => { n.firstChild.data='frame '+(++i); }, 5); })();")
        time.sleep(duration)
        browser.evaluate("clearInterval(window.__stop)")
        result = browser.evaluate("window.__auctionMetrics")
    return result


def main():
    new = shipped_js()
    initial, dynamic = run_functional(new)
    v6 = run_v6(new)
    old_metrics = run_perf(LEGACY_JS)
    new_metrics = run_perf(new)
    reduction = 100 * (1 - new_metrics["time"] / old_metrics["time"]) if old_metrics["time"] else 100.0
    print(json.dumps({
        "functional_initial": initial, "functional_dynamic": dynamic,
        "v6_bid_display": v6, "legacy_10s": old_metrics,
        "new_10s": new_metrics, "main_thread_reduction_percent": round(reduction, 3),
    }, ensure_ascii=False, indent=2))
    if reduction < 90:
        raise SystemExit(f"main-thread reduction {reduction:.3f}% is below 90%")


if __name__ == "__main__":
    main()
