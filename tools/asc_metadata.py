#!/usr/bin/env python3
"""Fill in everything App Store Connect needs for MindChuk 1.0 that the API allows:
name/subtitle, categories, description/keywords/URLs, age rating, copyright,
content rights, review contact, free price. App Privacy has no API and stays a phone task.
"""
import json
import os
import sys

from asc_common import APP_ID, api, app_info_id, app_info_localization, must, version_id, version_localization

SITE = "https://assiamahs.github.io/mindchuk"
CONTACT = {"firstName": "Sylvester", "lastName": "Assiamah",
           "email": os.environ.get("ASC_CONTACT_EMAIL", "pelotonysl@outlook.com"),
           "phone": os.environ.get("ASC_CONTACT_PHONE", "+19088390555")}

NAME = "MindChuk"
SUBTITLE = "Text yourself. Find it fast."
PROMO = "Send yourself anything. Tags file it, reminders ping you, search finds it. Private, on your iPhone."
DESCRIPTION = """MindChuk is the private feed for your brain. Text yourself anything: ideas, notes, links, grocery lists, random 2am thoughts. It is saved before the idea fades, and it is there when you need it.

SEND EVERYTHING. SORT NOTHING.
Type it like a text and hit send. No folders to pick, no forms to fill. Every message becomes a card in a clean, searchable feed.

TAGS FILE IT FOR YOU
Write #groceries anywhere in a note and it files itself under that tag. Give a tag trigger words (milk, eggs, limes) and any note with those words lands there too. Tags can live inside other tags.

REMINDERS FROM PLAIN WORDS
Start with "remind me" and say when. "Remind me at 9am to call the vet." "Remind me to call John in 30 minutes." "On Jan 30 submit report." MindChuk pings you at that time.

PHOTOS AND LINKS SAVE TOO
Attach photos with the paperclip. Paste a link and the card shows it ready to open.

THREE MORE WAYS TO SEE IT
Board: pick 2 to 5 tags and they become columns.
Calendar: see what was captured or is scheduled on any day.
Swipe: run through the deck one card at a time. Left archives, right keeps, up finishes.

PRIVATE BY DESIGN
There is no account, no server and no upload. Everything lives on your iPhone. Export a CSV of all your notes any time.

Light mode, four font styles, compact view, and search by text or date.

For minds that never turn off."""
KEYWORDS = "notes,capture,second brain,ideas,reminders,tags,journal,quick notes,text yourself,inbox,todo,lists"


def step(label, st, r):
    ok = st < 300
    print(f"{'ok ' if ok else 'ERR'} {label}: HTTP {st}" + ("" if ok else f" {json.dumps(r)[:600]}"))
    return ok


def main():
    vid, vattrs = version_id()
    print(f"version {vattrs['versionString']} ({vattrs['appStoreState']})")
    aid = app_info_id()

    # --- App Information (all platforms) ---
    loc = app_info_localization(aid)
    st, r = api("PATCH", f"/v1/appInfoLocalizations/{loc}", {"data": {
        "type": "appInfoLocalizations", "id": loc,
        "attributes": {"name": NAME, "subtitle": SUBTITLE, "privacyPolicyUrl": f"{SITE}/privacy.html"}}})
    if not step("name / subtitle / privacy url", st, r):
        # name may be locked to what was typed at creation; retry without it
        st, r = api("PATCH", f"/v1/appInfoLocalizations/{loc}", {"data": {
            "type": "appInfoLocalizations", "id": loc,
            "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": f"{SITE}/privacy.html"}}})
        step("subtitle / privacy url (name kept)", st, r)

    st, r = api("PATCH", f"/v1/appInfos/{aid}", {"data": {
        "type": "appInfos", "id": aid,
        "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
            "secondaryCategory": {"data": {"type": "appCategories", "id": "UTILITIES"}}}}})
    step("categories Productivity / Utilities", st, r)

    st, r = api("PATCH", f"/v1/apps/{APP_ID}", {"data": {
        "type": "apps", "id": APP_ID,
        "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    step("content rights: no third-party content", st, r)

    # --- Age rating: nothing objectionable -> 4+ (the API wants every question answered explicitly) ---
    st, r = api("GET", f"/v1/appInfos/{aid}/ageRatingDeclaration")
    if step("read age rating declaration", st, r):
        rid = r["data"]["id"]
        wanted = {
            "advertising": False, "gambling": False, "lootBox": False, "healthOrWellnessTopics": False,
            "messagingAndChat": False, "parentalControls": False, "socialMedia": False,
            "socialMediaAgeRestricted": False, "unrestrictedWebAccess": False, "userGeneratedContent": False,
            "ageAssurance": False,
            "alcoholTobaccoOrDrugUseOrReferences": "NONE", "contests": "NONE", "gamblingSimulated": "NONE",
            "gunsOrOtherWeapons": "NONE", "horrorOrFearThemes": "NONE", "matureOrSuggestiveThemes": "NONE",
            "medicalOrTreatmentInformation": "NONE", "profanityOrCrudeHumor": "NONE",
            "sexualContentGraphicAndNudity": "NONE", "sexualContentOrNudity": "NONE",
            "violenceCartoonOrFantasy": "NONE", "violenceRealistic": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
        }
        st, r = api("PATCH", f"/v1/ageRatingDeclarations/{rid}", {"data": {
            "type": "ageRatingDeclarations", "id": rid, "attributes": wanted}})
        if not step(f"age rating all NONE ({len(wanted)} keys)", st, r):
            # drop whatever keys this account's questionnaire rejects and retry once
            bad = [e.get("source", {}).get("pointer", "").split("/")[-1] for e in r.get("errors", [])]
            for k in bad:
                wanted.pop(k, None)
            st, r = api("PATCH", f"/v1/ageRatingDeclarations/{rid}", {"data": {
                "type": "ageRatingDeclarations", "id": rid, "attributes": wanted}})
            step(f"age rating retry without {bad}", st, r)
        if st >= 300:
            print("   age rating needs the phone questionnaire (answer No to everything)")

    # --- Version page ---
    st, r = api("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {
        "type": "appStoreVersions", "id": vid,
        "attributes": {"copyright": "2026 Sylvester Assiamah", "releaseType": "AFTER_APPROVAL"}}})
    step("copyright + release after approval", st, r)

    vloc = version_localization(vid)
    st, r = api("PATCH", f"/v1/appStoreVersionLocalizations/{vloc}", {"data": {
        "type": "appStoreVersionLocalizations", "id": vloc,
        "attributes": {"description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO,
                       "supportUrl": f"{SITE}/#support", "marketingUrl": SITE}}})
    step("description / keywords / promo / URLs", st, r)

    # --- App Review contact ---
    st, r = api("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    review_attrs = {"contactFirstName": CONTACT["firstName"], "contactLastName": CONTACT["lastName"],
                    "contactEmail": CONTACT["email"], "demoAccountRequired": False,
                    "notes": "MindChuk is a local-only notes app. No account, no server. "
                             "Type in the box at the bottom of Feed and send; add #tags; start a note with "
                             "'remind me at 9am to ...' to schedule a local notification."}
    if CONTACT["phone"]:
        review_attrs["contactPhone"] = CONTACT["phone"]
    if st == 200 and r.get("data"):
        rid = r["data"]["id"]
        st, r = api("PATCH", f"/v1/appStoreReviewDetails/{rid}", {"data": {
            "type": "appStoreReviewDetails", "id": rid, "attributes": review_attrs}})
    else:
        st, r = api("POST", "/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": review_attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    step("app review contact", st, r)

    # --- Price: free ---
    st, r = api("GET", f"/v1/apps/{APP_ID}/appPricePoints?filter[territory]=USA&limit=200")
    if step("read price points", st, r):
        free = [d for d in r["data"] if float(d["attributes"]["customerPrice"]) == 0.0]
        if free:
            pp = free[0]["id"]
            st, r = api("POST", "/v1/appPriceSchedules", {
                "data": {"type": "appPriceSchedules",
                         "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}},
                                           "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                                           "manualPrices": {"data": [{"type": "appPrices", "id": "${price-free}"}]}}},
                "included": [{"type": "appPrices", "id": "${price-free}",
                              "attributes": {"startDate": None},
                              "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": pp}}}}]})
            step("price schedule: Free (USA base)", st, r)

    # --- Availability: everywhere ---
    st, r = api("GET", "/v1/territories?limit=200")
    if step("read territories", st, r):
        terr = [{"type": "territories", "id": d["id"]} for d in r["data"]]
        st, r = api("POST", "/v2/appAvailabilities", {
            "data": {"type": "appAvailabilities",
                     "attributes": {"availableInNewTerritories": True},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}},
                                       "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": "${t-" + t["id"] + "}"} for t in terr]}}},
            "included": [{"type": "territoryAvailabilities", "id": "${t-" + t["id"] + "}", "attributes": {"available": True},
                          "relationships": {"territory": {"data": t}}} for t in terr]})
        step(f"availability: {len(terr)} territories", st, r)

    print("\nmetadata pass complete")


if __name__ == "__main__":
    main()
