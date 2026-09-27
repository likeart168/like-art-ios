#!/usr/bin/env python3
"""Bounded real WKWebView world run on a disposable simulator, never a fixture."""
import json,os,pathlib,subprocess,time,shutil
out=pathlib.Path('build-b2/evidence/world-entry-20');out.mkdir(parents=True,exist_ok=True)
def get(*args):return subprocess.check_output(args,text=True,timeout=60).strip()
def run(*args,**kw):return subprocess.run(args,check=True,timeout=kw.pop('timeout',180),**kw)
sdk=get('xcrun','--sdk','iphonesimulator','--show-sdk-version')
catalog=json.loads(get('xcrun','simctl','list','--json'))
runtime=next(r for r in reversed(catalog['runtimes']) if r.get('isAvailable') and r['name'].startswith('iOS ') and r['version'].split('.')[:2]==sdk.split('.')[:2])
type_=next(d for d in catalog['devicetypes'] if d['name']=='iPhone 17 Pro Max')
udid=get('xcrun','simctl','create','LikeArt World Evidence',type_['identifier'],runtime['identifier'])
(out/'environment.json').write_text(json.dumps({'sdk':sdk,'runtime':runtime,'device':type_},indent=2))
try:
 run('xcrun','simctl','boot',udid);run('xcrun','simctl','bootstatus',udid,'-b',timeout=300)
 run('xcrun','simctl','install',udid,'build-b2/Simulator/Build/Products/Debug-iphonesimulator/LikeArt.app')
 env=dict(os.environ,SIMCTL_CHILD_STORE_CAPTURE_PATH='/v6/?app=1&measure=1',SIMCTL_CHILD_WORLD_CAPTURE='1')
 run('xcrun','simctl','launch',udid,'com.likeart.app','-AppleLanguages','(zh-Hans)',env=env)
 container=pathlib.Path(get('xcrun','simctl','get_app_container',udid,'com.likeart.app','data'))
 for second in range(1,51):
  time.sleep(1)
  source=container/'Documents/world-entry-20.json'
  if source.exists():shutil.copy2(source,out/'samples.json')
  if second in (10,30,50):run('xcrun','simctl','io',udid,'screenshot',str(out/f'{second:02d}-seconds.png'))
 data=json.loads((out/'samples.json').read_text())
 ready=next((s for s in data['samples'] if s.get('page',{}).get('ready')),None)
 summary={'firstReadySample':None if not ready else ready['elapsed'],'webkitTerminations':data['terminations'],'last':data['samples'][-1]}
 (out/'summary.json').write_text(json.dumps(summary,indent=2))
 print(json.dumps({k:v for k,v in summary.items() if k!='last'}),flush=True)
 # Diagnostic-only commits must never be distributed; the workflow also skips signing/upload.
finally:
 subprocess.run(['xcrun','simctl','shutdown',udid],timeout=90)
 subprocess.run(['xcrun','simctl','delete',udid],timeout=90)
