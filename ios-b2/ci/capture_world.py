#!/usr/bin/env python3
"""Bounded real WKWebView world run on a disposable simulator, never a fixture."""
import json,os,pathlib,subprocess,time,shutil,re,signal,threading
out=pathlib.Path('build-b2/evidence/world-entry-20');out.mkdir(parents=True,exist_ok=True)
def get(*args):return subprocess.check_output(args,text=True,timeout=60).strip()
def run(*args,**kw):return subprocess.run(args,check=True,timeout=kw.pop('timeout',180),**kw)
sdk=get('xcrun','--sdk','iphonesimulator','--show-sdk-version')
catalog=json.loads(get('xcrun','simctl','list','--json'))
runtime=next(r for r in reversed(catalog['runtimes']) if r.get('isAvailable') and r['name'].startswith('iOS ') and r['version'].split('.')[:2]==sdk.split('.')[:2])
device_name=os.environ.get('WORLD_DEVICE','iPhone 13 Pro')
type_=next(d for d in catalog['devicetypes'] if d['name']==device_name)
udid=get('xcrun','simctl','create','LikeArt World Evidence',type_['identifier'],runtime['identifier'])
(out/'environment.json').write_text(json.dumps({'sdk':sdk,'runtime':runtime,'device':type_},indent=2))
app_pid=None;watchdog=None
def stop_app():
 # simctl terminate can hang when WebKit/GPU is wedged. The PID returned by our
 # own launch belongs only to this disposable app, never another simulator.
 if app_pid is not None:
  try:os.kill(app_pid,signal.SIGKILL)
  except ProcessLookupError:pass
try:
 run('xcrun','simctl','boot',udid);run('xcrun','simctl','bootstatus',udid,'-b',timeout=300)
 run('xcrun','simctl','install',udid,'build-b2/Simulator/Build/Products/Debug-iphonesimulator/LikeArt.app')
 env=dict(os.environ,SIMCTL_CHILD_STORE_CAPTURE_PATH='/v6/?app=1&measure=1',SIMCTL_CHILD_WORLD_CAPTURE='1')
 container=pathlib.Path(get('xcrun','simctl','get_app_container',udid,'com.likeart.app','data'))
 # A newly-created simulator is still doing first-boot background work after bootstatus.
 # Settle the OS before cold-launching the app; application entry timing is unchanged.
 print('Settling new simulator OS for 45 seconds before app launch',flush=True)
 time.sleep(45)
 began=time.monotonic();deadline=began+50
 launch=subprocess.check_output(['xcrun','simctl','launch',udid,'com.likeart.app','-AppleLanguages','(zh-Hans)'],env=env,text=True,timeout=30)
 print(launch,flush=True)
 match=re.search(r'com\.likeart\.app:\s*(\d+)',launch)
 assert match, 'Missing launched app PID; cannot enforce the watchdog'
 app_pid=int(match[1])
 watchdog=threading.Timer(max(0,began+55-time.monotonic()),stop_app);watchdog.daemon=True;watchdog.start()
 # A screenshot/blocked WebKit must not extend this into a 90+ second run.
 captured=set();capture_errors=[];process_samples=[];last_process=-5;gpu_profile=None
 while time.monotonic()<deadline:
  time.sleep(min(1,max(0,deadline-time.monotonic())))
  elapsed=time.monotonic()-began
  if elapsed-last_process>=5:
   last_process=elapsed
   try:
    processes=subprocess.check_output(['ps','-axo','pid,ppid,rss,pcpu,comm'],text=True,timeout=2)
    process_samples.append({'elapsed':elapsed,'rows':[r for r in processes.splitlines() if any(n in r for n in ['WebKit','LikeArt.app','Simulator.app','WindowServer','MTLCompilerService'])]})
    (out/'processes.json').write_text(json.dumps(process_samples,indent=2))
    if os.environ.get('WORLD_GPU_PROFILE') == '1' and elapsed>=25 and gpu_profile is None:
     parsed=[line.split(None,4) for line in processes.splitlines()[1:]]
     owner=next((line[1] for line in parsed if line[0]==str(app_pid)),None)
     gpu=next((line[0] for line in parsed if line[1]==owner and 'com.apple.WebKit.GPU' in line[-1]),None)
     if gpu:gpu_profile=subprocess.Popen(['sample',gpu,'1','-file',str(out/'gpu-stack.txt')],stdout=subprocess.DEVNULL,stderr=(out/'gpu-stack-error.txt').open('w'))
   except (subprocess.TimeoutExpired,subprocess.CalledProcessError):pass
  source=container/'Documents/world-entry-20.json'
  if source.exists():shutil.copy2(source,out/'samples.json')
  checks=container/'Documents/world-native-checks-20.json'
  if checks.exists():shutil.copy2(checks,out/'native-checks.json')
  for second in (40,):
   if second not in captured and time.monotonic()-began>=second and deadline-time.monotonic()>0.1:
    captured.add(second)
    # An unready GPU can wedge simctl screenshot itself and perturb the remaining
    # startup evidence. Capture the actual world only after a ready observation.
    observed=json.loads(source.read_text()) if source.exists() else {}
    if not any(row.get('page',{}).get('ready') for row in observed.get('samples',[])):continue
    try:run('xcrun','simctl','io',udid,'screenshot',str(out/f'{second:02d}-seconds.png'),timeout=min(8,deadline-time.monotonic()))
    except (subprocess.TimeoutExpired,subprocess.CalledProcessError) as error:capture_errors.append({'second':second,'error':str(error)})
 if gpu_profile is not None and gpu_profile.poll() is None:gpu_profile.terminate()
 # Stop the actual application before parsing evidence, even if assertions fail.
 stop_app()
 assert json.loads((out/'native-checks.json').read_text())['pass'], 'Native navigation/retry checks failed'
 data=json.loads((out/'samples.json').read_text())
 ready=next((s for s in data['samples'] if s.get('page',{}).get('ready')),None)
 ready_ms=None if not ready else ready['page'].get('readyWall',0)-data['beganEpochMs']
 summary={'device':device_name,'captureWallSeconds':time.monotonic()-began,'captureErrors':capture_errors,'readyMs':ready_ms,'firstReadySample':None if not ready else ready['elapsed'],'webkitTerminations':data['terminations'],'last':data['samples'][-1]}
 (out/'summary.json').write_text(json.dumps(summary,indent=2))
 print(json.dumps({k:v for k,v in summary.items() if k!='last'}),flush=True)
 if os.environ.get('WORLD_ACCEPTANCE') == '1':
  assert ready_ms is not None and 0 < ready_ms <= 10000, 'World entry must render within 10 seconds'
  assert data['terminations']==0, 'WebKit renderer terminated'
  assert all(not s.get('jsError') and not s.get('nativeFailed') and not s.get('page',{}).get('errors') and not s.get('page',{}).get('gpuEvents') for s in data['samples']), 'World startup/retention has errors'
  assert ready['page'].get('player'), 'World player missing'
 # Diagnostic-only commits must never be distributed; the workflow also skips signing/upload.
finally:
 stop_app()
 if watchdog is not None:watchdog.cancel()
 for action in ('shutdown','delete'):
  try:subprocess.run(['xcrun','simctl',action,udid],timeout=30)
  except subprocess.TimeoutExpired:print(f'Simulator cleanup timed out: {action}',flush=True)
