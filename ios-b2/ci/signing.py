#!/usr/bin/env python3
"""Prepare signing resources; never modify the app's source Info.plist."""
import base64, datetime, os, pathlib, plistlib, subprocess
root = pathlib.Path('build-b2')
root.mkdir(exist_ok=True)
for variable, source, destination in [('P12_CERTIFICATE', 'ios_distribution.p12', 'distribution.p12'), ('PROVISIONING_PROFILE', 'likeart_appstore.mobileprovision', 'profile.mobileprovision')]:
    value = os.environ.get(variable)
    target = root / destination
    if value:
        target.write_bytes(base64.b64decode(value, validate=True))
    elif pathlib.Path(source).is_file():
        target.write_bytes(pathlib.Path(source).read_bytes())
        print(f'{variable}: using existing repository signing resource')
    else:
        raise SystemExit(f'Missing secret: {variable}')
    target.chmod(0o600)
profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(root / 'profile.mobileprovision')]))
assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Provisioning profile expired'
assert profile['Entitlements']['application-identifier'] == '2JZCL349AG.com.likeart.app'
uuid = profile['UUID']
profiles = pathlib.Path.home() / 'Library/MobileDevice/Provisioning Profiles'
profiles.mkdir(parents=True, exist_ok=True)
(profiles / f'{uuid}.mobileprovision').write_bytes((root / 'profile.mobileprovision').read_bytes())
# APNs is only signed when the supplied profile has the capability provisioned.
entitlements = {}
for key in ['aps-environment', 'com.apple.developer.associated-domains']:
    if key in profile['Entitlements']:
        entitlements[key] = profile['Entitlements'][key]
(root / 'LikeArt.entitlements').write_bytes(plistlib.dumps(entitlements))
export = dict(method='app-store-connect', teamID='2JZCL349AG', signingStyle='manual', provisioningProfiles={'com.likeart.app': uuid}, signingCertificate='Apple Distribution', manageAppVersionAndBuildNumber=False, stripSwiftSymbols=True, uploadSymbols=True)
(root / 'ExportOptions.plist').write_bytes(plistlib.dumps(export))
with open(os.environ['GITHUB_ENV'], 'a') as output:
    output.write(f'PROFILE_UUID={uuid}\n')
summary = dict(name=profile['Name'], uuid=uuid, expires=profile['ExpirationDate'].isoformat(), apns=entitlements.get('aps-environment', 'NOT_PROVISIONED'), associatedDomains=entitlements.get('com.apple.developer.associated-domains', 'NOT_PROVISIONED'))
import json
(root / 'evidence/signing-profile.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
