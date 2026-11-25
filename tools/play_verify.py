"""Fails the build (so GitHub e-mails the owner) unless Google Play's track holds the expected version code."""
import json, os, sys

from google.oauth2 import service_account
from googleapiclient.discovery import build

PKG = "com.mawaqeety.app"
expected = int(os.environ["EXPECTED"])
track = os.environ.get("TRACK", "internal")
creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"])
edits = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()
edit = edits.insert(packageName=PKG, body={}).execute()["id"]
t = edits.tracks().get(packageName=PKG, editId=edit, track=track).execute()
codes = [int(v) for r in t.get("releases", []) for v in r.get("versionCodes", [])]
edits.delete(packageName=PKG, editId=edit).execute()
print(f"{track}: {t.get('releases')}")
newest = max(codes or [0])
if newest < expected:
    print(f"::error::Google Play {track} track has build {newest}, expected {expected}. The upload did not go through.")
    sys.exit(1)
print(f"OK: build {newest} is on the {track} track.")
with open(os.environ.get("GITHUB_STEP_SUMMARY", os.devnull), "a") as f:
    f.write(f"✅ Google Play ({track}): build {newest}\n")
