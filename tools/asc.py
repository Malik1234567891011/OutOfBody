"""Tiny App Store Connect API client (ES256 JWT via cryptography).
usage: python3 tools/asc.py GET /v1/apps/6837586861/appInfos
       python3 tools/asc.py PATCH /v1/... '{"data":{...}}'
Key lives outside the repo in ~/OutOfBody-secrets.
"""
import base64, json, os, sys, time
import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

KEY_ID = "SAZC7K29F8"
ISSUER = "d4439a1e-e613-450a-b9d4-9c6c2b5b488b"
KEY_PATH = os.path.expanduser("~/OutOfBody-secrets/AuthKey_SAZC7K29F8.p8")
BASE = "https://api.appstoreconnect.apple.com"


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def token():
    key = serialization.load_pem_private_key(open(KEY_PATH, "rb").read(), None)
    head = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    body = {"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}
    msg = (b64(json.dumps(head).encode()) + "." + b64(json.dumps(body).encode())).encode()
    r, s = decode_dss_signature(key.sign(msg, ec.ECDSA(hashes.SHA256())))
    return msg.decode() + "." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


def call(method, path, body=None):
    h = {"Authorization": "Bearer " + token(), "Content-Type": "application/json"}
    r = requests.request(method, BASE + path, headers=h, data=json.dumps(body) if body else None)
    try:
        return r.status_code, r.json()
    except Exception:
        return r.status_code, r.text


if __name__ == "__main__":
    m, p = sys.argv[1], sys.argv[2]
    b = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    code, out = call(m, p, b)
    print(code)
    print(json.dumps(out, indent=1)[:6000])
