"""Sends a build that Google Play already has to a testing track (closed testing = "alpha" by default).

Env: PLAY_SERVICE_ACCOUNT_JSON, VERSION_CODE (empty = newest on internal), TRACK (default alpha).
Release notes come from mobile/distribution/whatsnew/whatsnew-ar.
"""
import json, os, sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

PKG = "com.mawaqeety.app"
TRACK = os.environ.get("TRACK") or "alpha"
WANT = os.environ.get("VERSION_CODE", "").strip()


def summary(text):
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(text + "\n")


creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"])
api = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()

edit = api.insert(packageName=PKG, body={}).execute()["id"]
tracks = {t["track"]: t for t in api.tracks().list(packageName=PKG, editId=edit).execute().get("tracks", [])}
lines = ["| Track | Releases |", "|---|---|"]
for name, t in tracks.items():
    rel = ", ".join(f"{r.get('status')} {r.get('versionCodes', [])}" for r in t.get("releases", []))
    lines.append(f"| {name} | {rel or '-'} |")
summary("Before:\n\n" + "\n".join(lines))

code = WANT or str(max(int(v) for r in tracks.get("internal", {}).get("releases", []) for v in r.get("versionCodes", [])))
notes_file = os.path.join(os.path.dirname(__file__), "..", "mobile", "distribution", "whatsnew", "whatsnew-ar")
notes = [{"language": "ar", "text": open(notes_file, encoding="utf-8").read().strip()[:500]}]
try:
    api.tracks().update(packageName=PKG, editId=edit, track=TRACK, body={
        "track": TRACK,
        "releases": [{"versionCodes": [code], "status": "completed", "releaseNotes": notes}],
    }).execute()
    api.commit(packageName=PKG, editId=edit).execute()
except HttpError as e:
    summary(f"Google refused ({e.status_code}):\n\n```\n{str(e)[:1500]}\n```")
    sys.exit(1)
summary(f"Build {code} was sent to the '{TRACK}' track. Google reviews it before testers get it.")
