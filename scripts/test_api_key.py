import jwt, time, os, urllib.request, json

KEY_ID = os.environ["APPSTORE_KEY_ID"]
ISSUER_ID = os.environ["APPSTORE_ISSUER_ID"]

with open("certs/AuthKey.p8") as f:
    private_key = f.read()

now = int(time.time())
token = jwt.encode(
    {"iss": ISSUER_ID, "iat": now - 60, "exp": now + 300, "aud": "appstoreconnect-v1"},
    private_key,
    algorithm="ES256",
    headers={"kid": KEY_ID, "typ": "JWT"}
)

print(f"JWT generated: {len(token)} chars")
print(f"Key ID: {KEY_ID}")
print(f"Issuer: {ISSUER_ID}")

req = urllib.request.Request(
    "https://api.appstoreconnect.apple.com/v1/apps",
    headers={"Authorization": f"Bearer {token}"}
)
try:
    resp = urllib.request.urlopen(req)
    data = json.loads(resp.read())
    apps = data.get("data", [])
    print(f"SUCCESS: Found {len(apps)} app(s)")
    for app in apps:
        print(f"  - {app['attributes']['name']} ({app['id']}) bundleId={app['attributes']['bundleId']}")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"FAILED: HTTP {e.code}")
    print(body[:500])
except Exception as e:
    print(f"ERROR: {e}")
