"""Checks that each reciter folder on everyayah.com serves real MP3 files. Used by CI (verify-audio)."""
import json, sys, urllib.request

reciters = json.load(open("mobile/assets/data/reciters.json", encoding="utf-8"))
bad = []
for r in reciters:
    for f in ("001001", "002255", "114006"):
        url = f"https://everyayah.com/data/{r['id']}/{f}.mp3"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mawaqeety-CI"})
            data = urllib.request.urlopen(req, timeout=60).read()
            ok = len(data) > 3000 and (data[:3] == b"ID3" or (data[0] == 0xFF and data[1] & 0xE0 == 0xE0))
            msg = f"{len(data)} bytes"
        except Exception as e:
            ok, msg = False, str(e)
        print(("OK  " if ok else "BAD ") + f"{r['id']}/{f} {msg}", flush=True)
        if not ok:
            bad.append(r["id"])
print("BAD_IDS=" + ",".join(sorted(set(bad))))
sys.exit(1 if bad else 0)
