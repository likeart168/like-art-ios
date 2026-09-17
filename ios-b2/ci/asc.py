#!/usr/bin/env python3
"""ASC API authentication, upload through Apple tools, then exact-build verification.
JWT is generated here, never in embedded workflow Python or printed to logs.
"""
import base64, json, os, pathlib, subprocess, sys, time
import jwt
import requests

OUT = pathlib.Path('build-b2/evidence')
OUT.mkdir(parents=True, exist_ok=True)
KEY_ID = os.environ.get('APPSTORE_KEY_ID') or 'RA48U82CSV'
ISSUER = os.environ.get('APPSTORE_ISSUER_ID') or '8ad4234e-2fc0-4943-8cde-e8bff3541efb'
secret = os.environ.get('AUTHKEY_BASE64')
if not secret:
    missing = 'Missing repository secret: AUTHKEY_BASE64 (current AuthKey_RA48U82CSV.p8); APPSTORE_KEY_ID and APPSTORE_ISSUER_ID must match it.'
    (OUT / 'asc-upload-status.txt').write_text(missing + '\n')
    raise SystemExit(missing)
key = base64.b64decode(secret).decode()
private = pathlib.Path.home() / '.appstoreconnect/private_keys'
private.mkdir(parents=True, exist_ok=True)
key_path = private / f'AuthKey_{KEY_ID}.p8'
key_path.write_text(key)
key_path.chmod(0o600)

def api(path, params=None):
    now = int(time.time())
    token = jwt.encode({'iss': ISSUER, 'iat': now-10, 'exp': now+600, 'aud': 'appstoreconnect-v1'}, key, algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})
    response = requests.get('https://api.appstoreconnect.apple.com/v1/' + path, params=params, headers={'Authorization': 'Bearer ' + token}, timeout=60)
    if response.status_code != 200:
        (OUT / 'asc-error.json').write_text(response.text)
        raise RuntimeError(f'ASC HTTP {response.status_code}: {response.text}')
    return response.json()

try:
    print(f'ASC API key ID: {KEY_ID}', flush=True)
    if '--query-only' not in sys.argv:
        ipa = next(pathlib.Path('build-b2/export').glob('*.ipa'))
        available = []
        if subprocess.run(['xcrun', '--find', 'altool'], capture_output=True).returncode == 0:
            available.append(['xcrun', 'altool', '--upload-app', '-f', str(ipa), '-t', 'ios', '--apiKey', KEY_ID, '--apiIssuer', ISSUER])
        if subprocess.run(['xcrun', '--find', 'iTMSTransporter'], capture_output=True).returncode == 0:
            available.append(['xcrun', 'iTMSTransporter', '-m', 'upload', '-assetFile', str(ipa), '-apiKey', KEY_ID, '-apiIssuer', ISSUER])
        transporter = pathlib.Path('/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter')
        if transporter.exists():
            available.append([str(transporter), '-m', 'upload', '-assetFile', str(ipa), '-apiKey', KEY_ID, '-apiIssuer', ISSUER])
        assert available, 'Neither altool nor Transporter is available in the selected Xcode runner'
        uploaded = False
        for command in available:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=1200)
            print(result.stdout, flush=True)
            with (OUT / 'asc-upload.txt').open('a') as output:
                output.write(result.stdout)
            if result.returncode == 0:
                uploaded = True
                break
    apps = api('apps', {'filter[bundleId]': 'com.likeart.app'})
    assert len(apps['data']) == 1, 'Expected exactly one ASC app for com.likeart.app'
    app_id = apps['data'][0]['id']
    (OUT / 'asc-app.json').write_text(json.dumps(apps, indent=2))
    if '--query-only' not in sys.argv:
        assert uploaded, 'Apple upload tools failed; see asc-upload.txt. IPA artifact is retained.'
    build_number = os.environ['BUILD_NUMBER']
    for attempt in range(40):
        result = api('builds', {'filter[app]': app_id, 'filter[version]': build_number, 'include': 'preReleaseVersion', 'limit': '10'})
        (OUT / 'asc-build.json').write_text(json.dumps(result, indent=2))
        print(json.dumps(result, indent=2), flush=True)
        for build in result['data']:
            state = build['attributes']['processingState']
            if state == 'VALID':
                groups = api('builds/' + build['id'] + '/betaGroups')
                (OUT / 'asc-beta-groups.json').write_text(json.dumps(groups, indent=2))
                (OUT / 'asc-upload-status.txt').write_text(f'VALID build {build_number}; build id {build["id"]}\n')
                sys.exit(0)
            if state in ['INVALID', 'FAILED']:
                raise RuntimeError(f'ASC processing state: {state}')
        time.sleep(30)
    raise RuntimeError(f'Build {build_number} did not become VALID within 20 minutes')
except Exception as error:
    (OUT / 'asc-upload-status.txt').write_text(str(error) + '\n')
    raise
finally:
    key_path.unlink(missing_ok=True)
