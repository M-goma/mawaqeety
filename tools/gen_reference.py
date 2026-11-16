"""Independent reference values (astral library, NOAA algorithms) used by the unit tests.
Output: tests/Mawaqeety.Tests/reference_times.json  — UTC ISO instants."""
import json, os, datetime as dt
from astral import Observer
from astral import sun

cases = [
  ("Cairo", 30.0444, 31.2357, 19.5, 17.5),
  ("Makkah", 21.4225, 39.8262, 18.5, None),
  ("London", 51.5072, -0.1276, 18, 17),
  ("New York", 40.7128, -74.0060, 15, 15),
  ("Jakarta", -6.2088, 106.8456, 20, 18),
  ("Sydney", -33.8688, 151.2093, 18, 17),
  ("Casablanca", 33.5731, -7.5898, 19, 17),
]
dates = [dt.date(2026,1,1), dt.date(2026,3,20), dt.date(2026,6,21), dt.date(2026,9,23), dt.date(2026,11,16), dt.date(2027,2,10)]
out = []
for name, lat, lng, fa, ia in cases:
    obs = Observer(latitude=lat, longitude=lng, elevation=0)
    for d in dates:
        # astral works on the UTC date; use the local solar date by passing a tz-aware date via local noon
        rec = {"City": name, "Lat": lat, "Lng": lng, "Date": d.isoformat(), "FajrAngle": fa, "IshaAngle": ia}
        tzinfo = dt.timezone(dt.timedelta(hours=round(lng/15)))
        rec["Sunrise"] = sun.sunrise(obs, d, tzinfo=tzinfo).astimezone(dt.timezone.utc).isoformat()
        rec["Sunset"] = sun.sunset(obs, d, tzinfo=tzinfo).astimezone(dt.timezone.utc).isoformat()
        rec["Noon"] = sun.noon(obs, d, tzinfo=tzinfo).astimezone(dt.timezone.utc).isoformat()
        def safe(f, dep):
            try: return f(obs, d, tzinfo=tzinfo, depression=dep).astimezone(dt.timezone.utc).isoformat()
            except ValueError: return None  # sun never reaches the angle (high latitude summer)
        rec["Fajr"] = safe(sun.dawn, fa)
        rec["Isha"] = safe(sun.dusk, ia) if ia else None
        out.append(rec)
p = os.path.join(os.path.dirname(__file__), "..", "tests", "Mawaqeety.Tests", "reference_times.json")
json.dump(out, open(p, "w"), indent=1)
print(len(out), "reference rows")
