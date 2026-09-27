// The native bridge reads only public entries in the checksum-verified archive.
// Responses and blobs are constructed in the HTTPS page's own origin.
(function () {
  if (window.__v6PackShim || !/^https:\/\/(www\.)?like-art\.com$/.test(location.origin) ||
      !location.pathname.startsWith('/v6/') || /^\/v6\/(clips|live)\//.test(location.pathname)) return;
  const bridge = window.webkit?.messageHandlers?.likeArtWorldPack;
  if (!bridge?.postMessage) return;
  const catalog = __QUERIES__, entries = __ENTRIES__.filter(p => Object.hasOwn(catalog, p));
  const available = new Set(entries), originalFetch = window.fetch.bind(window);
  const stats = window.__v6PackShim = {transport:'native-message-22',entries:entries.length,ready:!!entries.length,hits:0,fallbacks:0,bytes:0,failures:[]};
  if (!stats.ready) return;
  window.__V6_PACK_PATHS__ = new Set(entries.map(p => '/v6/' + p));
  navigator.serviceWorker?.getRegistrations().then(rs => {
    for (const r of rs) if (new URL(r.scope).pathname === '/v6/') void r.unregister();
  }).catch(() => {});
  const failure = (path, error) => {
    stats.fallbacks++;
    if (stats.failures.length < 16) stats.failures.push({path,reason:String(error)});
  };
  function key(input) {
    try {
      const u = new URL(typeof input === 'string' ? input : input.url || String(input), location.href);
      if (u.origin !== location.origin || !u.pathname.startsWith('/v6/')) return null;
      const p = u.pathname.slice(4);
      return available.has(p) && (!u.search || catalog[p].includes(u.search)) ? p : null;
    } catch { return null; }
  }
  const aborted = signal => { if (signal?.aborted) throw signal.reason || new DOMException('Aborted','AbortError'); };
  const queue = []; let active = 0;
  function drain() {
    while (active < 2 && queue.length) {
      const job = queue.shift(); active++;
      Promise.resolve().then(job.work).then(job.resolve,job.reject).finally(() => { active--; drain(); });
    }
  }
  function read(path, signal) {
    return new Promise((resolve,reject) => {
      queue.push({resolve,reject,work:async () => {
        aborted(signal);
        let output, offset = 0, total, mime;
        do {
          aborted(signal);
          let timer;
          const part = await Promise.race([
            bridge.postMessage({path,offset}),
            new Promise((_,fail) => {timer=setTimeout(()=>fail(new Error('Native pack read timed out')),8000);}),
          ]).finally(()=>clearTimeout(timer));
          aborted(signal);
          if (!Number.isSafeInteger(part.total) || part.total <= 0 || part.total > 64*1024*1024 || part.offset !== offset || typeof part.base64 !== 'string') throw new Error('Invalid native pack chunk');
          if (!output) {total=part.total;mime=part.mime;output=new Uint8Array(total);}
          if (total !== part.total) throw new Error('Native pack size changed');
          const chunk = atob(part.base64);
          if (!chunk.length || chunk.length > 1024*1024 || offset+chunk.length > total) throw new Error('Native pack chunk bounds');
          for (let i=0;i<chunk.length;i++) output[offset+i]=chunk.charCodeAt(i);
          offset+=chunk.length;
        } while (offset < total);
        stats.hits++;stats.bytes+=total;
        return {bytes:output,mime};
      }});drain();
    });
  }
  window.fetch = async function(input, init={}) {
    const path=key(input), method=init.method || input?.method || 'GET', signal=init.signal || input?.signal;
    const headers=new Headers(init.headers || input?.headers);
    if (!path || method.toUpperCase() !== 'GET' || (init.credentials || input?.credentials)==='include' ||
        (init.mode || input?.mode)==='no-cors' || headers.has('Range') || headers.has('Authorization')) return originalFetch(input,init);
    try {
      const data=await read(path,signal);
      const response=new Response(data.bytes,{status:200,headers:{'Content-Type':data.mime,'Content-Length':String(data.bytes.byteLength),'X-LikeArt-Pack':'native-message-22'}});
      Object.defineProperty(response,'url',{value:new URL(typeof input==='string'?input:input.url || String(input),location.href).href});
      return response;
    } catch(error) {aborted(signal);failure(path,error);return originalFetch(input,init);}
  };
  const proto=XMLHttpRequest.prototype, open=proto.open, send=proto.send, abort=proto.abort, setHeader=proto.setRequestHeader;
  const requests=new WeakMap();
  proto.open=function(method,url,async=true,user,password) {
    const old=requests.get(this);old?.controller.abort();
    requests.set(this,{args:Array.from(arguments),path:method.toUpperCase()==='GET' && async!==false && !user && !password ? key(url):null,headers:[],controller:new AbortController(),pending:false});
    return open.apply(this,arguments);
  };
  proto.setRequestHeader=function(name,value) {requests.get(this)?.headers.push([name,value]);return setHeader.apply(this,arguments);};
  proto.abort=function() {
    const state=requests.get(this);const pending=state?.pending;state?.controller.abort();if(state)state.pending=false;
    const result=abort.call(this);
    if(pending){this.dispatchEvent(new ProgressEvent('abort'));this.dispatchEvent(new ProgressEvent('loadend'));}
    return result;
  };
  proto.send=function(body) {
    const state=requests.get(this);
    if(!state?.path || this.withCredentials || state.headers.some(([n])=>/^(range|authorization)$/i.test(n)))return send.call(this,body);
    const xhr=this, responseType=this.responseType, timeout=this.timeout, started=Date.now();state.pending=true;
    const reopen = url => {
      const args=state.args.slice();args[1]=url;open.apply(xhr,args);xhr.responseType=responseType;
      xhr.timeout=timeout ? Math.max(1,timeout-(Date.now()-started)):0;
      for(const [name,value] of state.headers)setHeader.call(xhr,name,value);
    };
    read(state.path,state.controller.signal).then(data=>{
      aborted(state.controller.signal);if(requests.get(xhr)!==state)return;
      const blob=URL.createObjectURL(new Blob([data.bytes],{type:data.mime}));
      xhr.addEventListener('loadend',()=>URL.revokeObjectURL(blob),{once:true});
      try{reopen(blob);state.pending=false;send.call(xhr,body);}catch(error){URL.revokeObjectURL(blob);throw error;}
    }).catch(error=>{
      if(state.controller.signal.aborted || requests.get(xhr)!==state)return;
      state.pending=false;failure(state.path,error);
      try{reopen(state.args[1]);send.call(xhr,body);}catch{ xhr.dispatchEvent(new ProgressEvent('error'));xhr.dispatchEvent(new ProgressEvent('loadend')); }
    });
  };
  const media=new WeakMap(), liveURLs=new Set();
  for(const Type of [HTMLImageElement,HTMLMediaElement]) {
    const desc=Object.getOwnPropertyDescriptor(Type.prototype,'src');if(!desc?.set)continue;
    Object.defineProperty(Type.prototype,'src',{configurable:true,enumerable:desc.enumerable,get:desc.get,set(value){
      const previous=media.get(this);previous?.controller.abort();if(previous?.url){URL.revokeObjectURL(previous.url);liveURLs.delete(previous.url);}
      const path=key(value), state={controller:new AbortController(),url:null};media.set(this,state);
      if(!path)return desc.set.call(this,value);
      const element=this;
      read(path,state.controller.signal).then(data=>{
        aborted(state.controller.signal);if(media.get(element)!==state)return;
        const url=URL.createObjectURL(new Blob([data.bytes],{type:data.mime}));state.url=url;liveURLs.add(url);
        if(Type===HTMLImageElement){const clear=()=>{URL.revokeObjectURL(url);liveURLs.delete(url);};element.addEventListener('load',clear,{once:true});element.addEventListener('error',clear,{once:true});}
        desc.set.call(element,url);
      }).catch(error=>{if(!state.controller.signal.aborted && media.get(element)===state){failure(path,error);desc.set.call(element,value);}});
    }});
  }
  const NativeAudio=window.Audio;
  if(NativeAudio){const LocalAudio=function Audio(src){const element=new NativeAudio();if(src!==undefined)element.src=src;return element;};LocalAudio.prototype=NativeAudio.prototype;Object.setPrototypeOf(LocalAudio,NativeAudio);window.Audio=LocalAudio;}
  addEventListener('pagehide',()=>{for(const url of liveURLs)URL.revokeObjectURL(url);liveURLs.clear();},{once:true});
})();
