import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../Resources/world-pack-transport.js',import.meta.url),'utf8');
function fixture({fail=false,delay=0}={}) {
  const bytes=Buffer.alloc(2*1024*1024+39);for(let i=0;i<bytes.length;i++)bytes[i]=i%251;
  const network=[],chunks=[];let concurrent=0,maxConcurrent=0;
  class Element extends EventTarget {get src(){return this.value || ''}set src(v){this.value=v;queueMicrotask(()=>this.dispatchEvent(new Event('load')));}}
  class Media extends Element {};
  Object.defineProperty(Media.prototype,'src',Object.getOwnPropertyDescriptor(Element.prototype,'src'));
  const origFetch=async (url)=>{if(String(url).startsWith('blob:'))return fetch(url);network.push(String(url));return new Response('network',{status:200});};
  class XHR extends EventTarget {
    withCredentials=false;responseType='';timeout=0;readyState=0;
    open(method,url,async=true){this.method=method;this.url=url;this.readyState=1;this.responseType='';}
    setRequestHeader(){}
    abort(){this.readyState=0;}
    async send(){const r=await origFetch(this.url);this.status=r.status;this.response=this.responseType==='arraybuffer'?await r.arrayBuffer():await r.text();this.readyState=4;this.dispatchEvent(new Event('loadend'));}
  }
  const context={window:null,location:new URL('https://like-art.com/v6/?app=1'),navigator:{},fetch:origFetch,
    XMLHttpRequest:XHR,HTMLImageElement:Element,HTMLMediaElement:Media,Headers,Response,URL,Blob,AbortController,DOMException,
    Event,ProgressEvent:Event,atob,Uint8Array,setTimeout,clearTimeout,addEventListener:()=>{},
    webkit:{messageHandlers:{likeArtWorldPack:{async postMessage({path,offset}){
      concurrent++;maxConcurrent=Math.max(maxConcurrent,concurrent);chunks.push({path,offset});
      try {if(delay)await new Promise(r=>setTimeout(r,delay));if(fail)throw new Error('read failed');return {offset,total:bytes.length,mime:'model/gltf-binary',base64:bytes.subarray(offset,offset+1024*1024).toString('base64')};}
      finally{concurrent--;}
    }}}}};
  context.window=context;vm.createContext(context);vm.runInContext(source.replace('__QUERIES__',JSON.stringify({'assets/test.glb':['?v=known']})).replace('__ENTRIES__',JSON.stringify(['assets/test.glb'])),context);
  return {context,bytes,network,chunks,maxConcurrent:()=>maxConcurrent};
}
test('native chunks reconstruct exact bytes and normal response semantics',async()=>{
  const f=fixture(),r=await f.context.fetch('/v6/assets/test.glb?v=known');
  assert.equal(r.status,200);assert.equal(r.url,'https://like-art.com/v6/assets/test.glb?v=known');
  assert.deepEqual(Buffer.from(await r.arrayBuffer()),f.bytes);assert.equal(f.chunks.length,3);assert.equal(f.network.length,0);
});
test('unknown versions and authenticated/range/non-GET requests stay on network',async()=>{
  const f=fixture();await f.context.fetch('/v6/assets/test.glb?v=new');await f.context.fetch('/v6/assets/test.glb',{credentials:'include'});
  await f.context.fetch('/v6/assets/test.glb',{headers:{Range:'bytes=0-10'}});await f.context.fetch('/v6/assets/test.glb',{method:'POST'});
  assert.equal(f.network.length,4);assert.equal(f.chunks.length,0);
});
test('failed native read falls back exactly once and records a specific reason',async()=>{
  const f=fixture({fail:true}),r=await f.context.fetch('/v6/assets/test.glb');assert.equal(await r.text(),'network');
  assert.equal(f.network.length,1);assert.equal(f.context.__v6PackShim.fallbacks,1);assert.match(f.context.__v6PackShim.failures[0].reason,/read failed/);
});
test('cancellation stops native chunks and does not start network fallback',async()=>{
  const f=fixture({delay:10}),c=new AbortController();const pending=f.context.fetch('/v6/assets/test.glb',{signal:c.signal});
  setTimeout(()=>c.abort(),1);await assert.rejects(pending,{name:'AbortError'});assert.equal(f.network.length,0);assert.equal(f.chunks.length,1);
});
test('multiple assets stay within two simultaneous chunk transfers',async()=>{
  const f=fixture({delay:2});await Promise.all(Array.from({length:5},()=>f.context.fetch('/v6/assets/test.glb')));assert.equal(f.maxConcurrent(),2);
});
test('XHR receives identical ArrayBuffer via origin-owned Blob',async()=>{
  const f=fixture(),x=new f.context.XMLHttpRequest();x.open('GET','/v6/assets/test.glb?v=known');x.responseType='arraybuffer';
  const done=new Promise(r=>x.addEventListener('loadend',r,{once:true}));x.send();await done;
  assert.equal(x.status,200);assert.deepEqual(Buffer.from(x.response),f.bytes);assert.equal(f.network.length,0);
});
test('XHR abort during bridge read cannot send a late request',async()=>{
  const f=fixture({delay:10}),x=new f.context.XMLHttpRequest();x.open('GET','/v6/assets/test.glb');x.send();x.abort();
  await new Promise(r=>setTimeout(r,25));assert.equal(x.readyState,0);assert.equal(f.network.length,0);
});
