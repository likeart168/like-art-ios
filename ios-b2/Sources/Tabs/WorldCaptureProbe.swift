#if DEBUG
import WebKit

// Captures only the public guest world in an explicitly requested CI run.
// No diagnostic upload or capture hooks are compiled into Release archives.
@MainActor
final class WorldCaptureProbe {
    static let errorScript = """
    (()=>{
    let world20ReadyValue=window.ready;
    Object.defineProperty(window,'ready',{configurable:true,get:()=>world20ReadyValue,set:value=>{world20ReadyValue=value;if(value===true&&!window.__world20ReadyWall)window.__world20ReadyWall=Date.now();}});
    window.__world20Errors=[];window.__world20Gpu=[];
    addEventListener('webglcontextlost',e=>__world20Gpu.push({kind:'contextlost',at:performance.now(),message:e.statusMessage}),true);
    addEventListener('webglcontextrestored',()=>__world20Gpu.push({kind:'contextrestored',at:performance.now()}),true);
    const original=WebGL2RenderingContext.prototype.createRenderbuffer;
    WebGL2RenderingContext.prototype.createRenderbuffer=function(){const value=original.call(this);if(!value && __world20Gpu.length<30)__world20Gpu.push({kind:'null-renderbuffer',at:performance.now(),lost:this.isContextLost(),error:this.getError(),width:this.drawingBufferWidth,height:this.drawingBufferHeight});return value;};
    addEventListener('error',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.message||'resource error'));});
    addEventListener('unhandledrejection',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.reason));});
    })();
    """
    private var started = false
    private var samples: [[String: Any]] = []
    private var began = Date()
    private var terminations = 0
    func terminated() { terminations += 1; save() }
    private func save() {
        let record: [String: Any] = ["beganEpochMs":began.timeIntervalSince1970*1000, "samples": samples, "terminations": terminations, "elapsed": Date().timeIntervalSince(began)]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: directory.appendingPathComponent("world-entry-20.json"), options: .atomic)
        }
    }
    func start(_ view: WKWebView, state: WebState) {
        guard ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1", !started else { return }
        started = true; began = Date(); save()
        Task { await worldEntryNativeChecks20() }
        sample(view, state: state, remaining: 48)
    }
    private func sample(_ view: WKWebView, state: WebState, remaining: Int) {
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak view, weak state] in
            guard let self, let view, let state else { return }
            let script = """
            (()=>{const p=window.__TERRAIN_PREVIEW__,a=p?.app;
              return JSON.stringify({path:location.pathname,now:performance.now(),ready:window.ready===true,readyWall:window.__world20ReadyWall,
                loading:document.querySelector('#load-status')?.textContent,progress:document.querySelector('#load-fill')?.style.width,
                errors:window.__world20Errors,gpuEvents:window.__world20Gpu,graphics:window.__V6_GRAPHICS_STARTUP__,startup:window.__V6_STARTUP_RESOURCES__,
                stages:(window.__TASK119_TRACE__||[]).filter(x=>x.kind==='stage-start'||x.kind==='stage-end').map(({name,kind,ts})=>({name,kind,ts})),
                assets:a?.assets?.list().length,vram:a?.graphicsDevice?._vram,
                textures:Array.from(a?.graphicsDevice?.textures||[]).map(t=>({name:t.name,w:t.width,h:t.height,bytes:t._gpuSize})).sort((a,b)=>(b.bytes||0)-(a.bytes||0)).slice(0,24),
                player:p?.playerSystem?.state,
                resources:performance.getEntriesByType('resource').map(x=>({name:new URL(x.name).pathname,start:x.startTime,duration:x.duration,bytes:x.transferSize}))});})();
            """
            view.evaluateJavaScript(script) { value, error in
                var record: [String: Any] = ["elapsed":Date().timeIntervalSince(self.began),"nativeLoading":state.loading,"nativeFailed":state.failed,"nativeFailure":state.failureReason,"jsError":error?.localizedDescription ?? "", "jsErrorDetail":(error as NSError?)?.userInfo["WKJavaScriptExceptionMessage"] as? String ?? ""]
                if let text = value as? String, let data = text.data(using: .utf8), let page = try? JSONSerialization.jsonObject(with: data) { record["page"] = page }
                self.samples.append(record); self.save()
                self.sample(view, state: state, remaining:remaining-1)
            }
        }
    }
}
#endif
