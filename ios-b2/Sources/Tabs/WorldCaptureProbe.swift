#if DEBUG
import WebKit

// Captures only the public guest world in an explicitly requested CI run.
// No diagnostic upload or capture hooks are compiled into Release archives.
@MainActor
final class WorldCaptureProbe {
    static let errorScript = """
    window.__world20Errors=[];
    addEventListener('error',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.message||'resource error'));});
    addEventListener('unhandledrejection',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.reason));});
    """
    private var started = false
    private var samples: [[String: Any]] = []
    private var began = Date()
    private var terminations = 0
    func terminated() { terminations += 1; save() }
    private func save() {
        let record: [String: Any] = ["samples": samples, "terminations": terminations, "elapsed": Date().timeIntervalSince(began)]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: directory.appendingPathComponent("world-entry-20.json"), options: .atomic)
        }
    }
    func start(_ view: WKWebView, state: WebState) {
        guard ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1", !started else { return }
        started = true; began = Date(); save()
        sample(view, state: state, remaining: 48)
    }
    private func sample(_ view: WKWebView, state: WebState, remaining: Int) {
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak view, weak state] in
            guard let self, let view, let state else { return }
            let script = """
            (()=>{const p=window.__TERRAIN_PREVIEW__,a=p?.app;
              return JSON.stringify({path:location.pathname,now:performance.now(),ready:window.ready===true,
                loading:document.querySelector('#load-status')?.textContent,progress:document.querySelector('#load-fill')?.style.width,
                errors:window.__world20Errors,graphics:window.__V6_GRAPHICS_STARTUP__,startup:window.__V6_STARTUP_RESOURCES__,
                stages:(window.__TASK119_TRACE__||[]).filter(x=>x.kind==='stage-start'||x.kind==='stage-end').map(({name,kind,ts})=>({name,kind,ts})),
                assets:a?.assets?.list().length,vram:a?.graphicsDevice?._vram,
                player:p?.playerSystem?.state,
                resources:performance.getEntriesByType('resource').map(x=>({name:new URL(x.name).pathname,start:x.startTime,duration:x.duration,bytes:x.transferSize}))});})();
            """
            view.evaluateJavaScript(script) { value, error in
                var record: [String: Any] = ["elapsed":Date().timeIntervalSince(self.began),"nativeLoading":state.loading,"nativeFailed":state.failed,"nativeFailure":state.failureReason,"jsError":error?.localizedDescription ?? ""]
                if let text = value as? String, let data = text.data(using: .utf8), let page = try? JSONSerialization.jsonObject(with: data) { record["page"] = page }
                self.samples.append(record); self.save()
                self.sample(view, state: state, remaining:remaining-1)
            }
        }
    }
}
#endif
