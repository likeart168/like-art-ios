#if DEBUG
import WebKit

// Real simulator evidence only. This code is absent from Release archives.
@MainActor
func scheduleClipsCaptureProbe(_ webView: WKWebView) {
    guard ProcessInfo.processInfo.environment["STORE_CAPTURE_PATH"]?.hasPrefix("/clips") == true else { return }
    guard let tracked = webView as? ClipsViewportWebView, tracked.window != nil, !tracked.captureProbeStarted else { return }
    tracked.captureProbeStarted = true
    func sample(_ remaining: Int) {
        guard let view = webView as? ClipsViewportWebView else { return }
        guard let window = view.window else {
            if remaining > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sample(remaining - 1) } }
            return
        }
        let script = """
        (() => {
          const frame = document.querySelector('.clips-frame');
          const d = frame?.contentDocument || document, w = d.defaultView;
          const rect = s => { const r = d.querySelector(s)?.getBoundingClientRect(); return r ? {x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom} : null; };
          const v = d.querySelector('video[src]');
          return {url:location.pathname,viewport:{width:w.innerWidth,height:w.innerHeight},video:rect('video[src]'),feed:rect('#feed'),header:rect('.viewer-top'),footer:rect('.viewer-bottom'),meta:rect('.video-meta'),native:d.documentElement.dataset.nativeClips || null,insets:{top:getComputedStyle(d.documentElement).getPropertyValue('--clips-safe-top'),bottom:getComputedStyle(d.documentElement).getPropertyValue('--clips-safe-bottom')},playback:v?{paused:v.paused,time:v.currentTime,ready:v.readyState,inline:v.playsInline,controls:v.controls,fit:getComputedStyle(v).objectFit}:null,fullscreen:!!d.fullscreenElement};
        })();
        """
        view.evaluateJavaScript(script) { value, error in
            let frame = view.convert(view.bounds, to: window)
            var record: [String: Any] = ["windowWidth": window.bounds.width, "windowHeight": window.bounds.height,
                "webX": frame.minX, "webY": frame.minY, "webWidth": frame.width, "webHeight": frame.height,
                "safeTop": view.safeAreaInsets.top, "safeBottom": view.safeAreaInsets.bottom,
                "error": error?.localizedDescription ?? ""]
            record["page"] = value ?? NSNull()
            let page = value as? [String: Any]
            let playback = page?["playback"] as? [String: Any]
            let video = page?["video"] as? [String: Any]
            let ready = error == nil && page?["native"] as? String == "19"
                && playback?["paused"] as? Bool == false && (playback?["time"] as? Double ?? 0) > 0
                && abs(frame.minY) < 2 && abs(frame.height - window.bounds.height) < 2
                && abs(CGFloat(video?["height"] as? Double ?? 0) - window.bounds.height) < 2
            record["ready"] = ready
            record["samplesRemaining"] = remaining
            if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
               let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? data.write(to: directory.appendingPathComponent("clips-immersive-19.json"))
            }
            if !ready && remaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sample(remaining - 1) }
            }
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sample(24) }
}
#endif
