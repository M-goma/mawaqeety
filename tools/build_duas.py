"""Builds src/Mawaqeety.Core/Resources/duas.json (desktop: occasion duas from Hisn al-Muslim).
The mobile app has the whole book instead: mobile/assets/data/hisn.json (tools/build_hisn.py).

Text (fully vowelled): github.com/osamayy/azkar-db (azkar.json)
Sources (footnotes of the book): github.com/rn0x/hisn_almuslim_json (hisn_almuslim.json)
Usage: python3 tools/build_duas.py <azkar.json> <hisn_almuslim.json>
"""
import json, re, sys

DB, HISN = sys.argv[1], sys.argv[2]
rows = json.load(open(DB, encoding="utf-8"))["rows"]
hisn = json.load(open(HISN, encoding="utf-8"))

# group id, title, emoji, [db category names]
GROUPS = [
    ("sleep", "أذكار النوم", "🌙", ["أذكار النوم", "الدعاء إذا تقلب في الليل", "دعاء الفزع في النوم و من بلي بالوحشة", "ما يفعل من رأى الرؤيا أو الحلم في النوم"]),
    ("wake", "الاستيقاظ من النوم", "🌅", ["أذكار الاستيقاظ من النوم"]),
    ("travel", "السفر", "✈️", ["دعاء الركوب", "دعاء السفر", "التكبير و التسبيح في سير السفر", "دعاء دخول القرية أو البلدة",
                                "الدعاء إذا نزل مترلا في سفر أو غيره", "دعاء المسافر للمقيم", "دعاء المقيم للمسافر", "دعاء المسافر إذا أسحر", "ذكر الرجوع من السفر"]),
    ("after_prayer", "بعد الصلاة", "🕌", ["الأذكار بعد السلام من الصلاة"]),
    ("mosque", "المسجد والأذان", "🕋", ["أذكار الآذان", "دعاء الذهاب إلى المسجد", "دعاء دخول المسجد", "دعاء الخروج من المسجد"]),
    ("home", "المنزل", "🏠", ["الذكر عند الخروج من المنزل", "الذكر عند دخول المنزل"]),
    ("food", "الطعام", "🍽️", ["الدعاء قبل الطعام", "الدعاء عند الفراغ من الطعام", "دعاء الضيف لصاحب الطعام", "الدعاء عند إفطار الصائم", "الدعاء إذا أفطر عند أهل بيت"]),
    ("rain", "المطر والريح", "🌧️", ["دعاء الريح", "دعاء الرعد", "من أدعية الاستسقاء", "الدعاء إذا نزل المطر", "الذكر بعد نزول المطر", "من أدعية الاستصحاء"]),
    ("distress", "الهم والكرب", "💚", ["دعاء الهم والحزن", "دعاء الكرب", "دعاء من استصعب عليه أمر", "دعاء قضاء الدين", "دعاء من أصيب بمصيبة",
                                      "الدعاء حينما يقع ما لا يرضاه أو غلب على أمره"]),
    ("istikhara", "الاستخارة", "🤲", ["دعاء صلاة الاستخارة"]),
    ("wudu", "الوضوء والخلاء", "💧", ["دعاء دخول الخلاء", "دعاء الخروج من الخلاء", "الذكر قبل الوضوء", "الذكر بعد الفراغ من الوضوء"]),
    ("clothes", "اللباس", "👕", ["دعاء لبس الثوب", "دعاء لبس الثوب الجديد", "ما يقول إذا وضع الثوب"]),
    ("sick", "المريض", "🩺", ["الدعاء للمريض في عيادته", "ما يقول من أحس وجعا في جسده", "دعاء من رأى مبتلى"]),
    ("istighfar", "الاستغفار والتوبة", "🌿", ["الاستغفار و التوبة", "ما يقول ويفعل من أذنب ذنبا"]),
    ("misc", "أدعية متفرقة", "✨", ["دعاء رؤية الهلال", "دعاء الغضب", "دعاء العطاس", "كفارة اﻟﻤﺠلس", "الدعاء لمن صنع إليك معروفا", "دعاء دخول السوق", "دعاء كراهية الطيرة"]),
]


def norm(s):
    s = s.replace("ﺗﻬ", "ته").replace("اﻟﻤﺠ", "المج").replace("مترلا", "منزلا").replace("الآذان", "الأذان")
    return re.sub(r"[\sً-ْ،,؟?]|و(?=\s)", "", s)

hisn_by = {norm(k): v for k, v in hisn.items()}
ALIAS = {  # azkar-db name -> Hisn al-Muslim chapter name
    "الدعاء إذا تقلب في الليل": "الدعاء إذا تقلب ليلاً",
    "دعاء الفزع في النوم و من بلي بالوحشة": "دعاء القلق والفزع في النوم ومن بلي بالوحشة",
    "ما يفعل من رأى الرؤيا أو الحلم في النوم": "ما يفعل من رأى الرؤيا أو الحلم",
    "دعاء الركوب": "دعاء ركوب الدابة",
    "التكبير و التسبيح في سير السفر": "التكبير والتسبيح في سير السفر",
    "الذكر عند دخول المنزل": "الذكر عند الدخول المنزل",
    "دعاء قضاء الدين": "الدعاء قضاء الدين",
    "كفارة اﻟﻤﺠلس": "كفارة المجلس ومايختم به المجالس",
    "الدعاء إذا نزل مترلا في سفر أو غيره": "الدعاء إذا نزل منزلا في سفر أو غيره",
    "الاستغفار و التوبة": "الاستغفار والتوبة",
}


def clean(t):
    t = t.replace("((", "«").replace("))", "»").replace("ﺗﻬ", "ته").replace("اﻟﻤﺠ", "المج")
    t = re.sub(r"[ \t]+", " ", t)
    return t.strip()


def title(c):
    return c.replace("ﺗﻬ", "ته").replace("اﻟﻤﺠ", "المج").replace("مترلا", "منزلا").replace("الآذان", "الأذان").replace(" و ", " و").strip()


out = []
for gid, gtitle, emoji, cats in GROUPS:
    sections = []
    for c in cats:
        items = [r for r in rows if r[0] == c]
        assert items, c
        h = hisn.get(ALIAS[c]) if c in ALIAS else hisn_by.get(norm(c))
        notes = [n.strip() for n in (h or {}).get("footnote", []) if n.strip()]
        sec = {"title": title(c), "items": []}
        for i, r in enumerate(items):
            it = {"text": clean(r[1])}
            if r[3] not in ("", None) and int(r[3]) > 1:
                it["count"] = int(r[3])
            if r[2]:
                it["virtue"] = clean(r[2])
            src = r[4] or (notes[i] if len(notes) == len(items) else "")
            if src:
                it["source"] = clean(src)
            sec["items"].append(it)
        if notes and len(notes) != len(items):
            sec["sources"] = notes
        sections.append(sec)
    out.append({"id": gid, "title": gtitle, "emoji": emoji, "sections": sections})

meta = {"source": "حصن المسلم من أذكار الكتاب والسنة — د. سعيد بن علي بن وهف القحطاني", "groups": out}
for path in ("src/Mawaqeety.Core/Resources/duas.json",):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
print(sum(len(s["items"]) for g in out for s in g["sections"]), "duas in", len(out), "groups")
