#if DEBUG
import WebKit

// Captures only the public guest world in an explicitly requested CI run.
// No diagnostic upload or capture hooks are compiled into Release archives.
@MainActor
final class WorldCaptureProbe: NSObject, WKScriptMessageHandler {
    private final class ViewRecord {
        weak var view: WKWebView?
        let tab: Int
        init(_ view: WKWebView, tab: Int) { self.view = view; self.tab = tab }
    }
    private static var views: [ViewRecord] = []
    static func register(_ view: WKWebView, tab: Int) {
        guard ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1" else { return }
        views.removeAll { $0.view == nil }
        views.append(ViewRecord(view, tab: tab))
    }
    static let errorScript = """
    (()=>{
    if(new URL(location.href).searchParams.get('probeAvatar')==='mushroom'){
      const originalFetch=window.fetch.bind(window);
      window.fetch=async function(input,init){const result=await originalFetch(input,init);
        if(new URL(typeof input==='string'?input:input.url,location.href).pathname!=='/v6/api/spawn')return result;
        const body=await result.json(),avatar={id:'artist-mushroom-2667-168',revision:'avatar-141',height:3};
        body.avatar=avatar;body.identity={...body.identity,avatar};body.spawn={x:35,y:8.7,z:-20};body.region='market';
        window.__world30AvatarFixture=true;return new Response(JSON.stringify(body),{status:200,headers:{'Content-Type':'application/json'}});
      };
    }
    window.__afterLanguage25=performance.now();
    let world20ReadyValue=window.ready;
    Object.defineProperty(window,'ready',{configurable:true,get:()=>world20ReadyValue,set:value=>{world20ReadyValue=value;if(value===true&&!window.__world20ReadyWall)window.__world20ReadyWall=Date.now();}});
    window.__world20Errors=[];window.__world20Gpu=[];
    let traceCount=0;
    const trace=(kind,detail={})=>{if(traceCount++<8000)window.webkit?.messageHandlers?.worldCaptureTrace?.postMessage({kind,at:performance.now(),...detail});};
    let earlyApp;
    Object.defineProperty(window,'__V6_ENTRY_APP__',{configurable:true,get:()=>earlyApp,set:a=>{
      earlyApp=a;trace('app-created');
      a?.assets?.on('load',asset=>trace('asset-loaded',{name:asset.name,type:asset.type}));
      a?.assets?.on('error',(error,asset)=>trace('asset-error',{name:asset?.name,error:String(error)}));
    }});
    // GL call-by-call IPC perturbs the timed run; opt in only for fault localization.
    if(new URL(location.href).searchParams.get('glTrace')==='1' && window.WebGL2RenderingContext){for(const name of ['compileShader','linkProgram','getProgramParameter','getActiveUniform','getUniformLocation']){
      const original=WebGL2RenderingContext.prototype[name];if(!original)continue;
      WebGL2RenderingContext.prototype[name]=function(...args){
        if(name==='bufferData' && (args[1]?.byteLength||args[1]||0)<500000)return original.apply(this,args);
        trace('gl-begin',{name,parameter:typeof args[1]==='number'?args[1]:0});
        try{return original.apply(this,args);}finally{trace('gl-end',{name});}
      };
    }}
    addEventListener('webglcontextlost',e=>__world20Gpu.push({kind:'contextlost',at:performance.now(),message:e.statusMessage}),true);
    addEventListener('webglcontextrestored',()=>__world20Gpu.push({kind:'contextrestored',at:performance.now()}),true);
    if(window.WebGL2RenderingContext){
      const original=WebGL2RenderingContext.prototype.createRenderbuffer;
      // Do not call getError(): it consumes the error before the engine can inspect it.
      WebGL2RenderingContext.prototype.createRenderbuffer=function(){const value=original.call(this);if(!value && __world20Gpu.length<30)__world20Gpu.push({kind:'null-renderbuffer',at:performance.now(),lost:this.isContextLost(),width:this.drawingBufferWidth,height:this.drawingBufferHeight});return value;};
    }
    addEventListener('error',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.message||'resource error'));});
    addEventListener('unhandledrejection',e=>{if(__world20Errors.length<30)__world20Errors.push(String(e.reason));});
    })();
    """
    private var started = false
    private var samples: [[String: Any]] = []
    private var began = Date()
    private var preparationBegan: Date?
    private var terminations = 0
    private var traceEvents: [[String: Any]] = []
    private var traceSavePending = false
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let event = message.body as? [String: Any] else { return }
        traceEvents.append(event)
        if traceEvents.count > 200 { traceEvents.removeFirst(traceEvents.count - 200) }
        guard !traceSavePending else { return }
        traceSavePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.traceSavePending = false; self?.save()
        }
    }
    func markEntryRequested() {
        guard preparationBegan == nil else { return }
        preparationBegan = Date()
    }
    func terminated() { terminations += 1; save() }
    private func save() {
        let webViews: [[String: Any]] = Self.views.compactMap { item in
            guard let view = item.view else { return nil }
            return ["tab":item.tab,"path":view.url?.path ?? "", "attached":view.window != nil,"hidden":view.isHidden,"loading":view.isLoading]
        }
        let record: [String: Any] = ["beganEpochMs":began.timeIntervalSince1970*1000, "samples": samples, "trace":traceEvents, "terminations": terminations, "elapsed": Date().timeIntervalSince(began),"webViews":webViews,"packEnabled":NativeReleasePolicy.bundledWorldPackEnabled]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: directory.appendingPathComponent("world-entry-20.json"), options: .atomic)
        }
    }
    func start(_ view: WKWebView, state: WebState) {
        guard ProcessInfo.processInfo.environment["WORLD_CAPTURE"] == "1", !started,
              let url = view.url, AppSession.allowed(url),
              ["/v6", "/v6/", "/v6/index.html"].contains(url.path) else { return }
        started = true; began = preparationBegan ?? Date(); save()
        Task { await worldEntryNativeChecks20() }
        sample(view, state: state, remaining: 48)
    }
    private func sample(_ view: WKWebView, state: WebState, remaining: Int) {
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak view, weak state] in
            guard let self, let view, let state else { return }
            let script = """
            (()=>{const p=window.__TERRAIN_PREVIEW__,a=p?.app||window.__V6_ENTRY_APP__;
              if(window.ready && !window.__world35Walk && p?.playerSystem){
                window.__world35Walk={before:p.playerSystem.audit().position,started:performance.now()};
                document.querySelector('#spawn-guide-skip')?.click();
                window.dispatchEvent(new KeyboardEvent('keydown',{key:'s',code:'KeyS',bubbles:true}));
                setTimeout(()=>{window.dispatchEvent(new KeyboardEvent('keyup',{key:'s',code:'KeyS',bubbles:true}));window.__world35Walk.after=p.playerSystem.audit().position;},1200);
              }
              return JSON.stringify({path:location.pathname,now:performance.now(),documentStart:window.__documentStart25,afterLanguage:window.__afterLanguage25,ready:window.ready===true,readyWall:window.__world20ReadyWall,
                walk:window.__world35Walk,diagnostics:p?.worldDiagnostics?.snapshot(),
                loading:document.querySelector('#load-status')?.textContent,progress:document.querySelector('#load-fill')?.style.width,
                errors:window.__world20Errors,gpuEvents:window.__world20Gpu,graphics:window.__V6_GRAPHICS_STARTUP__,startup:window.__V6_STARTUP_RESOURCES__,renderStartup:window.__V6_STARTUP_RENDER_22__,
                stages:(window.__TASK119_TRACE__||[]).filter(x=>x.kind==='stage-start'||x.kind==='stage-end').map(({name,kind,ts})=>({name,kind,ts})),
                astcSupported:!!a?.graphicsDevice?.extCompressedTextureASTC,astc:a?.graphicsDevice?.__worldAstc32?.snapshot(),avatarFixture:window.__world30AvatarFixture,decoder:window.__V6_DECODER_RECYCLE_27__?.stats,streamHandoff:a?.assets?.__v6ContainerLoadGuard?.handoff,emptyLight:a?.scene?.__worldEmptyLight25,textureResidency:a?.graphicsDevice?.__worldTextureResidency25?.snapshot(),bufferResidency:a?.graphicsDevice?.__worldBufferResidency25?.snapshot(),physicalBufferBytes:Array.from(a?.graphicsDevice?.buffers||[]).filter(b=>b.impl?.bufferId).reduce((n,b)=>n+(b.numBytes||0),0),
                assets:a?.assets?.list().length,vram:a?.graphicsDevice?._vram,pack:window.__v6PackShim,exactTerrain:window.__V6_EXACT_TERRAIN_212__,entry:window.__V6_ENTRY__,
                containerGuard:(()=>{const g=window.__V6_CONTAINER_LOAD_GUARD__;return g?{version:g.version,phase:g.phase(),queued:g.queued(),active:g.active(),aheadHits:g.readAheadHits,aheadBytes:g.readAheadBytes,pause:g.pauseReason(),processed:g.processed}:null})(),
                scenery:p?Object.fromEntries(['meadowLifeSystem','worldDistanceSystem','skyBirdsSystem','marketFarSystem','faunaSystem','meatsDollSystem'].map(k=>[k,{status:p[k]?.status,errors:p[k]?.errors,error:p[k]?.error}])):null,
                loadingAssets:a?.assets?.list().filter(x=>x.loading).map(x=>({name:x.name,type:x.type})),visibility:document.visibilityState,
                navigation:performance.getEntriesByType('navigation').map(n=>({fetchStart:n.fetchStart,domainLookupStart:n.domainLookupStart,domainLookupEnd:n.domainLookupEnd,connectStart:n.connectStart,connectEnd:n.connectEnd,requestStart:n.requestStart,responseStart:n.responseStart,responseEnd:n.responseEnd,domInteractive:n.domInteractive,domComplete:n.domComplete})),viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,canvas:[...document.querySelectorAll('canvas')].map(c=>({id:c.id,width:c.width,height:c.height}))},
                renderTargets:Array.from(a?.graphicsDevice?.targets||[]).map(t=>({name:t.name,w:t.width,h:t.height,samples:t.samples})),
                textures:Array.from(a?.graphicsDevice?.textures||[]).map(t=>({name:t.name,w:t.width,h:t.height,bytes:t._gpuSize})).sort((a,b)=>(b.bytes||0)-(a.bytes||0)).slice(0,24),
                player:p?.playerSystem?.state,
                resources:performance.getEntriesByType('resource').map(x=>({name:new URL(x.name).pathname,start:x.startTime,duration:x.duration,bytes:x.transferSize}))});})();
            """
            view.evaluateJavaScript(script) { value, error in
                var record: [String: Any] = ["webURL":view.url?.absoluteString ?? "", "estimatedProgress":view.estimatedProgress,"elapsed":Date().timeIntervalSince(self.began),"nativeLoading":state.loading,"nativeFailed":state.failed,"nativeFailure":state.failureReason,"jsError":error?.localizedDescription ?? "", "jsErrorDetail":(error as NSError?)?.userInfo["WKJavaScriptExceptionMessage"] as? String ?? ""]
                let pack = WorldPack.shared.stats
                record["nativePack"] = ["served":pack.served,"missed":pack.missed,"ready":pack.ready]
                if let text = value as? String, let data = text.data(using: .utf8), let page = try? JSONSerialization.jsonObject(with: data) { record["page"] = page }
                self.samples.append(record); self.save()
                self.sample(view, state: state, remaining:remaining-1)
            }
        }
    }
}
#endif
