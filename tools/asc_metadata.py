"""Fill the App Store listing for OutOfBody v1.0 via the ASC API (idempotent)."""
import json, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from asc import call

APP = "6837586861"
APPINFO = "d27fe0d3-3ec4-45b5-a2c3-b2b28c875e7f"
APPINFO_LOC = "aa65102b-48bc-42de-881b-eb1cdc26f32e"
VERSION = "0e44e0cc-711f-4b34-8ca6-345fa2fb8872"
VERSION_LOC = "fa6c5bee-a18f-402c-b389-8d3a0a22c22f"

DESCRIPTION = """Quit vaping or Zyn without white-knuckling it.

OutOfBody turns your habit into real numbers, then steps you down to zero with a daily budget that shrinks every week. No cold-turkey crash. No shame when you slip.

SEE WHAT YOUR VAPE REALLY IS
Tell us what you use and how much. We convert it into milligrams of nicotine, packs of cigarettes and dollars a year. Most people are surprised.

A PLAN THAT STEPS YOU DOWN
Pick your pace: 2, 4, 6 or 8 weeks. Every week your daily budget drops a little, so no single day is a cliff. Nicotine-free by a date you can see.

LOG IN ONE TAP, FROM YOUR LOCK SCREEN
Tap the widget each time you pick it up. No unlocking, no app to open. Seeing the number is half the work.

CRAVING SOS
Cravings peak and fade within minutes. Hit SOS, breathe with a 90-second guide, read your own reasons, and log the win.

CHECK-INS WHEN IT'S HARDEST
Gentle reminders at the moments you told us are toughest: after meals, on the drive home, before bed.

A PLAN THAT ADAPTS
Rough week? Stay on your current step another week instead of failing. Every week ends with a short review.

STAY FREE
After quit day, track days nicotine-free, keep SOS handy, and log a slip without losing your progress.

PRIVATE BY DESIGN
No account. Your plan, logs and reasons stay on your phone.

OutOfBody Pro: 7-day free trial, then $39.99 CAD per year (or $3.99 CAD per week). Subscriptions renew automatically unless canceled at least 24 hours before the end of the period. Manage in Settings > your name > Subscriptions.

OutOfBody is a habit tool, not medical advice. Nicotine numbers are estimates.

Terms: https://outofbody.vercel.app/terms
Privacy: https://outofbody.vercel.app/privacy"""

KEYWORDS = "quit vaping,vape,zyn,nicotine,pouches,quit smoking,juul,elf bar,craving,taper,tracker,habit"
PROMO = "Your vape, in packs and dollars. Then a plan that steps you down to zero."


def p(label, code, out):
    ok = 200 <= code < 300
    print(("OK " if ok else "ERR ") + label, code, "" if ok else json.dumps(out)[:600])


p("appInfoLoc", *call("PATCH", f"/v1/appInfoLocalizations/{APPINFO_LOC}", {"data": {"type": "appInfoLocalizations", "id": APPINFO_LOC, "attributes": {
    "subtitle": "Step down, quit for good", "privacyPolicyUrl": "https://outofbody.vercel.app/privacy"}}}))

p("categories", *call("PATCH", f"/v1/appInfos/{APPINFO}", {"data": {"type": "appInfos", "id": APPINFO, "relationships": {
    "primaryCategory": {"data": {"type": "appCategories", "id": "HEALTH_AND_FITNESS"}},
    "secondaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}}}}}))

p("versionLoc", *call("PATCH", f"/v1/appStoreVersionLocalizations/{VERSION_LOC}", {"data": {"type": "appStoreVersionLocalizations", "id": VERSION_LOC, "attributes": {
    "description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO,
    "supportUrl": "https://outofbody.vercel.app/support", "marketingUrl": "https://outofbody.vercel.app"}}}))

p("version", *call("PATCH", f"/v1/appStoreVersions/{VERSION}", {"data": {"type": "appStoreVersions", "id": VERSION, "attributes": {
    "copyright": "2026 CielPM, Inc."}}}))

# age rating: frequent tobacco/nicotine references -> 18+
code, out = call("GET", f"/v1/appInfos/{APPINFO}/ageRatingDeclaration")
if code == 200:
    arid = out["data"]["id"]
    attrs = {k: "NONE" for k, v in out["data"]["attributes"].items() if isinstance(v, str) and v in ("NONE", "INFREQUENT_OR_MILD", "FREQUENT_OR_INTENSE")}
    attrs["alcoholTobaccoOrDrugUseOrReferences"] = "FREQUENT_OR_INTENSE"
    for k, v in out["data"]["attributes"].items():
        if isinstance(v, bool) or v is None:
            if k in ("gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "userGeneratedContent", "advertising", "ageAssurance", "parentalControls", "healthOrWellnessTopics", "kidsAgeBand"):
                pass
    for b in ("gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "userGeneratedContent", "advertising", "ageAssurance", "parentalControls"):
        if b in out["data"]["attributes"]:
            attrs[b] = False
    if "healthOrWellnessTopics" in out["data"]["attributes"]:
        attrs["healthOrWellnessTopics"] = True
    p("ageRating", *call("PATCH", f"/v1/ageRatingDeclarations/{arid}", {"data": {"type": "ageRatingDeclarations", "id": arid, "attributes": attrs}}))
else:
    p("ageRating GET", code, out)
