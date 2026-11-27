"""Updates the Google Play store listing: title, short description and the 512×512 icon.

Env: PLAY_SERVICE_ACCOUNT_JSON, TITLE, SHORT (short description), ICON (path, optional).
Applies to every listing language the app has (the Arabic one first).
"""
import json, os, sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

PKG = "com.mawaqeety.app"
TITLE, SHORT, ICON = os.environ["TITLE"].strip(), os.environ.get("SHORT", "").strip(), os.environ.get("ICON", "").strip()


def summary(text):
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(text + "\n")


if len(TITLE) > 30 or len(SHORT) > 80:
    sys.exit(f"Too long: title {len(TITLE)}/30, short description {len(SHORT)}/80")

creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"])
api = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()
edit = api.insert(packageName=PKG, body={}).execute()["id"]
try:
    listings = api.listings().list(packageName=PKG, editId=edit).execute().get("listings", [])
    summary("Before: " + ", ".join(f"{l['language']}: {l.get('title')}" for l in listings))
    for l in listings:
        body = {"title": TITLE}
        if SHORT:
            body["shortDescription"] = SHORT
        api.listings().patch(packageName=PKG, editId=edit, language=l["language"], body=body).execute()
        if ICON:
            api.images().deleteall(packageName=PKG, editId=edit, language=l["language"], imageType="icon").execute()
            api.images().upload(packageName=PKG, editId=edit, language=l["language"], imageType="icon",
                                media_body=MediaFileUpload(ICON, mimetype="image/png")).execute()
    api.commit(packageName=PKG, editId=edit).execute()
except HttpError as e:
    summary(f"Google refused ({e.status_code}):\n\n```\n{str(e)[:1500]}\n```")
    sys.exit(1)
summary(f"Listing updated: «{TITLE}». Google reviews it before it appears in the store.")
