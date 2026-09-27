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
platforms = json.loads(get('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
devices = [d for runtime, rows in platforms.items() if 'iOS' in runtime for d in rows]
phone = next((d for d in devices if d['name'] == 'iPhone 17 Pro Max'), None) or next(d for d in devices if 'Pro Max' in d['name'])
tablet = next(d for d in devices if 'iPad Pro 13-inch' in d['name'])
app = 'build-b2/Simulator/Build/Products/Debug-iphonesimulator/LikeArt.app'
manifest = []
scenes = [('01-art-market', '/?app=1', 25), ('02-clips', '/clips?app=1', 25), ('03-community', '/community?app=1', 25), ('04-live', '/live?app=1', 25), ('05-profile', 'profile', 10), ('06-world', '/v6/?app=1', 45)]
for kind, device in [('iphone', phone), ('ipad', tablet)]:
    udid = device['udid']
    try:
        if device['state'] != 'Booted': run('xcrun','simctl','boot',udid)
        run('xcrun','simctl','bootstatus',udid,'-b',timeout=300)
        run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
        for language, apple in [('en-US','en'), ('ru','ru'), ('zh-Hans','zh-Hans')]:
            subprocess.run(['xcrun','simctl','uninstall',udid,'com.likeart.app'],check=False,timeout=90)
            run('xcrun','simctl','install',udid,app)
            for scene, route, wait in scenes:
                environment = dict(os.environ, SIMCTL_CHILD_STORE_CAPTURE_PATH=route)
                run('xcrun','simctl','launch','--terminate-running-process',udid,'com.likeart.app','-AppleLanguages','('+apple+')','-AppleLocale',language,env=environment)
                time.sleep(wait)
                target = out / language / kind / (scene + '.png')
                target.parent.mkdir(parents=True,exist_ok=True)
                run('xcrun','simctl','io',udid,'screenshot',str(target))
                manifest.append({'file':str(target.relative_to(out)), 'device':device['name'], 'language':language, 'path':route, 'method':'simctl actual native app screenshot', 'data':'live public guest pages; no fixtures'})
                print('CAPTURED', str(target), flush=True)
    finally:
        subprocess.run(['xcrun','simctl','shutdown',udid],check=False,timeout=90)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
