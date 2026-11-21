"""Upload App Store screenshots (6.9"/6.7" set) for OutOfBody v1.0 via ASC API."""
import glob, hashlib, os, sys, time
import requests
sys.path.insert(0, os.path.dirname(__file__))
from asc import call

LOC = "fa6c5bee-a18f-402c-b389-8d3a0a22c22f"
DISPLAY = "APP_IPHONE_67"
files = sorted(glob.glob(os.path.expanduser("~/OutOfBody/store/appstore_*.png")))

code, out = call("GET", f"/v1/appStoreVersionLocalizations/{LOC}/appScreenshotSets")
sets = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in out.get("data", [])}
if DISPLAY in sets:
    sid = sets[DISPLAY]
    c, o = call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots")
    for s in o.get("data", []):
        call("DELETE", f"/v1/appScreenshots/{s['id']}")
else:
    c, o = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": LOC}}}}})
    print("set", c); sid = o["data"]["id"]

for f in files:
    data = open(f, "rb").read()
    c, o = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})
    if c != 201:
        print("create fail", f, c, str(o)[:300]); continue
    shot = o["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        hdr = {h["name"]: h["value"] for h in op["requestHeaders"]}
        r = requests.request(op["method"], op["url"], headers=hdr, data=chunk)
        if r.status_code >= 300:
            print("chunk fail", r.status_code)
    c, o = call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(os.path.basename(f), c)

time.sleep(8)
c, o = call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots")
for s in o.get("data", []):
    print(s["attributes"]["fileName"], s["attributes"]["assetDeliveryState"]["state"])
