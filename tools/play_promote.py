"""Daily check: once Google allows production releases, promote the newest tested build to production.

Runs only the first public release by default (does nothing if production already has a release),
unless FORCE=true. Writes a short status to $GITHUB_OUTPUT (result=published|waiting|already) and to the job summary.
"""
import json, os, sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

PKG = "com.mawaqeety.app"
FORCE = os.environ.get("FORCE", "false") == "true"


def out(key, value):
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"{key}<<EOF\n{value}\nEOF\n")


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
summary("\n".join(lines))

prod = [r for r in tracks.get("production", {}).get("releases", []) if r.get("versionCodes")]
if prod and not FORCE:
    summary("Production already has a release: nothing to do.")
    out("result", "already")
    sys.exit(0)

# Newest build from the testing tracks (closed testing first, then internal).
best = 0
for name in ("alpha", "beta", "internal"):
    for r in tracks.get(name, {}).get("releases", []):
        for v in r.get("versionCodes", []):
            best = max(best, int(v))
if not best:
    summary("No tested build found yet.")
    out("result", "waiting")
    sys.exit(0)

notes = [{"language": "ar", "text": "الإصدار الأول من مواقيتي: مواقيت الصلاة والأذان، القرآن الكريم مسموعًا، قصص الأنبياء، الأذكار، واتجاه القبلة."}]
try:
    api.tracks().update(packageName=PKG, editId=edit, track="production", body={
        "track": "production",
        "releases": [{"versionCodes": [str(best)], "status": "completed", "releaseNotes": notes}],
    }).execute()
    api.commit(packageName=PKG, editId=edit).execute()
except HttpError as e:
    msg = e.error_details if hasattr(e, "error_details") else str(e)
    summary(f"Production is not open yet (Google answered: {e.status_code}).\n\n```\n{str(msg)[:800]}\n```")
    out("result", "waiting")
    out("detail", str(msg)[:800])
    sys.exit(0)

summary(f"Build {best} was sent to production. Google reviews it before it appears in the store.")
out("result", "published")
out("version", str(best))
