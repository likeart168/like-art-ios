#!/usr/bin/env python3
"""Capture the actual Debug simulator app, with no fixtures or invented account data."""
import json, os, pathlib, subprocess, time
out = pathlib.Path('build-b2/evidence/store-screenshots')
out.mkdir(parents=True, exist_ok=True)
def run(*args, **kwargs):
    print("RUN", " ".join(args), flush=True)
    kwargs.setdefault("timeout", 180)
    return subprocess.run(args, check=True, text=True, **kwargs)
def get(*args):
    return subprocess.check_output(args, text=True)
# Avoid stale pre-created simulators and mismatched runtime/SDK combinations.
# Only these two disposable devices are booted, serially, and deleted on exit.
sdk = get('xcrun','--sdk','iphonesimulator','--show-sdk-version').strip()
catalog = json.loads(get('xcrun','simctl','list','--json'))
runtimes = [r for r in catalog['runtimes'] if r.get('isAvailable') and r['name'].startswith('iOS ') and r['version'].split('.')[:2] == sdk.split('.')[:2]]
assert runtimes, 'No installed iOS simulator runtime matching SDK '+sdk
runtime = runtimes[-1]
types = catalog['devicetypes']
phone_type = next(d for d in types if d['name']=='iPhone 17 Pro Max')
tablet_type = [d for d in types if d['name'].startswith('iPad Pro 13-inch')][-1]
def device(kind, spec):
    identifier = get('xcrun','simctl','create','LikeArt Store '+kind,spec['identifier'],runtime['identifier']).strip()
    return {'udid':identifier,'name':spec['name'],'state':'Shutdown'}
phone, tablet = device('iPhone',phone_type), device('iPad',tablet_type)
(out/'simulator-environment.json').write_text(json.dumps({'sdk':sdk,'runtime':runtime,'phone':phone,'tablet':tablet},indent=2)+'\n')
app = 'build-b2/Simulator/Build/Products/Debug-iphonesimulator/LikeArt.app'
manifest = []
scenes = [('01-art-market', '/?app=1', 25), ('02-clips', '/clips?app=1', 25), ('05-profile', 'profile', 12)]
for kind, device in [('iphone', phone), ('ipad', tablet)]:
    udid = device['udid']
    try:
        # Hosted macOS sometimes leaves a freshly booted simulator stuck.
        # Retry this disposable device once; never skip playback/layout assertions.
        for boot_attempt in range(2):
            try:
                if boot_attempt or device['state'] != 'Booted': run('xcrun','simctl','boot',udid)
                run('xcrun','simctl','bootstatus',udid,'-b',timeout=300)
                break
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                if boot_attempt: raise
                print('Simulator boot stalled; resetting this CI device once',flush=True)
                subprocess.run(['xcrun','simctl','shutdown',udid],check=False,timeout=90)
                run('xcrun','simctl','erase',udid)
        run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
        for language, apple in [('en-US','en'), ('ru','ru'), ('zh-Hans','zh-Hans')]:
            subprocess.run(['xcrun','simctl','uninstall',udid,'com.likeart.app'],check=False,timeout=90)
            run('xcrun','simctl','install',udid,app)
            for scene, route, wait in scenes:
                container = pathlib.Path(get('xcrun','simctl','get_app_container',udid,'com.likeart.app','data').strip())
                probe_path = container/'Documents/clips-immersive-19.json'
                if probe_path.exists(): probe_path.unlink()
                environment = dict(os.environ, SIMCTL_CHILD_STORE_CAPTURE_PATH=route)
                run('xcrun','simctl','launch','--terminate-running-process',udid,'com.likeart.app','-AppleLanguages','('+apple+')','-AppleLocale',language,env=environment)
                time.sleep(wait)
                if scene == '02-clips':
                    deadline = time.monotonic()+30
                    while time.monotonic()<deadline:
                        try:
                            if json.loads(probe_path.read_text()).get('ready'): break
                        except (FileNotFoundError,json.JSONDecodeError): pass
                        time.sleep(1)
                target = out / language / kind / (scene + '.png')
                target.parent.mkdir(parents=True,exist_ok=True)
                run('xcrun','simctl','io',udid,'screenshot',str(target))
                manifest.append({'file':str(target.relative_to(out)), 'device':device['name'], 'language':language, 'path':route, 'method':'simctl actual native app screenshot', 'data':'live public guest pages; no fixtures'})
                print('CAPTURED', str(target), flush=True)
                if scene == '02-clips':
                    container = pathlib.Path(get('xcrun','simctl','get_app_container',udid,'com.likeart.app','data').strip())
                    probe = json.loads((container/'Documents/clips-immersive-19.json').read_text())
                    (target.with_suffix('.json')).write_text(json.dumps(probe,indent=2)+'\n')
                    assert probe.get('ready') and not probe['error'], probe
                    assert abs(probe['webY']) < 2 and abs(probe['webHeight']-probe['windowHeight']) < 2, probe
                    page = probe['page']
                    assert page['native'] == '19' and not page['fullscreen'], probe
                    assert abs(page['video']['height']-probe['windowHeight']) < 2, probe
                    assert page['playback']['inline'] and not page['playback']['controls'] and page['playback']['fit']=='cover', probe
                    assert page['playback']['time'] > 0 and not page['playback']['paused'], probe
                    assert page['meta']['bottom'] < page['footer']['y'], probe
                    print('PASS IMMERSIVE19 native viewport and real inline playback',language,kind,flush=True)
    finally:
        subprocess.run(['xcrun','simctl','shutdown',udid],check=False,timeout=90)
        subprocess.run(['xcrun','simctl','delete',udid],check=False,timeout=90)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
