#!/usr/bin/env python3
"""Upload IPA to App Store Connect using REST API"""
import jwt, time, requests, os, sys

KEY_ID = os.environ["APPSTORE_KEY_ID"]
ISSUER_ID = os.environ["APPSTORE_ISSUER_ID"]
KEY_PATH = "certs/AuthKey.p8"

# Find IPA
import glob
ipas = glob.glob("build/**/*.ipa", recursive=True)
if not ipas:
    print("ERROR: No IPA found!")
    sys.exit(1)
IPA_PATH = ipas[0]
print(f"IPA: {IPA_PATH} ({os.path.getsize(IPA_PATH)} bytes)")

# Generate JWT
with open(KEY_PATH, 'r') as f:
    private_key = f.read()

now = int(time.time())
token = jwt.encode(
    {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1"
    },
    private_key,
    algorithm="ES256",
    headers={"kid": KEY_ID, "typ": "JWT"}
)
print(f"JWT generated (len={len(token)})")

# Get app info
headers = {"Authorization": f"Bearer {token}"}
r = requests.get("https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=com.likeart.app", headers=headers)
print(f"Apps API status: {r.status_code}")
if r.status_code == 200:
    apps = r.json()
    print(f"Found {len(apps.get('data',[]))} app(s)")
    for app in apps.get('data', []):
        print(f"  - {app['attributes']['name']} ({app['id']})")
else:
    print(f"Error: {r.text[:200]}")
    sys.exit(1)
