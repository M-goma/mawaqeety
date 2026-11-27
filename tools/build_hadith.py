"""Builds the Sahih al-Bukhari and Sahih Muslim data (Arabic, with official hadith numbers) for the apps.

Source: github.com/fawazahmed0/hadith-api (editions ara-bukhari, ara-muslim).
Output: mobile/assets/data/hadith_<id>.json.gz and src/Mawaqeety.Core/Resources/hadith_<id>.json.gz
  { "id", "name", "books": [[number, "name"], ...], "h": [[book, number, text, matnStart], ...] }
matnStart: character offset where the companion's narration starts (the text without the chain), or -1.
Usage: python3 tools/build_hadith.py <ara-bukhari.json> <ara-muslim.json>
"""
import gzip, json, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from hadith_matn import matn_start  # noqa: E402

BUKHARI = ["", "بدء الوحي", "الإيمان", "العلم", "الوضوء", "الغسل", "الحيض", "التيمم", "الصلاة", "مواقيت الصلاة", "الأذان",
           "الجمعة", "صلاة الخوف", "العيدين", "الوتر", "الاستسقاء", "الكسوف", "سجود القرآن", "تقصير الصلاة", "التهجد",
           "فضل الصلاة في مسجد مكة والمدينة", "العمل في الصلاة", "السهو", "الجنائز", "الزكاة", "الحج", "العمرة", "المحصر",
           "جزاء الصيد", "فضائل المدينة", "الصوم", "صلاة التراويح", "فضل ليلة القدر", "الاعتكاف", "البيوع", "السلم", "الشفعة",
           "الإجارة", "الحوالات", "الكفالة", "الوكالة", "المزارعة", "المساقاة", "الاستقراض وأداء الديون", "الخصومات", "اللقطة",
           "المظالم والغصب", "الشركة", "الرهن", "العتق", "المكاتب", "الهبة وفضلها", "الشهادات", "الصلح", "الشروط", "الوصايا",
           "الجهاد والسير", "فرض الخمس", "الجزية والموادعة", "بدء الخلق", "أحاديث الأنبياء", "المناقب", "فضائل أصحاب النبي ﷺ",
           "مناقب الأنصار", "المغازي", "التفسير", "فضائل القرآن", "النكاح", "الطلاق", "النفقات", "الأطعمة", "العقيقة",
           "الذبائح والصيد", "الأضاحي", "الأشربة", "المرضى", "الطب", "اللباس", "الأدب", "الاستئذان", "الدعوات", "الرقاق",
           "القدر", "الأيمان والنذور", "كفارات الأيمان", "الفرائض", "الحدود", "الديات", "استتابة المرتدين", "الإكراه", "الحيل",
           "التعبير", "الفتن", "الأحكام", "التمني", "أخبار الآحاد", "الاعتصام بالكتاب والسنة", "التوحيد"]
MUSLIM = ["المقدمة", "الإيمان", "الطهارة", "الحيض", "الصلاة", "المساجد ومواضع الصلاة", "صلاة المسافرين وقصرها", "الجمعة",
          "صلاة العيدين", "صلاة الاستسقاء", "الكسوف", "الجنائز", "الزكاة", "الصيام", "الاعتكاف", "الحج", "النكاح", "الرضاع",
          "الطلاق", "اللعان", "العتق", "البيوع", "المساقاة", "الفرائض", "الهبات", "الوصية", "النذر", "الأيمان",
          "القسامة والمحاربين والقصاص والديات", "الحدود", "الأقضية", "اللقطة", "الجهاد والسير", "الإمارة",
          "الصيد والذبائح وما يؤكل من الحيوان", "الأضاحي", "الأشربة", "اللباس والزينة", "الآداب", "السلام",
          "الألفاظ من الأدب وغيرها", "الشعر", "الرؤيا", "الفضائل", "فضائل الصحابة", "البر والصلة والآداب", "القدر", "العلم",
          "الذكر والدعاء والتوبة والاستغفار", "الرقاق", "التوبة", "صفات المنافقين وأحكامهم", "صفة القيامة والجنة والنار",
          "الجنة وصفة نعيمها وأهلها", "الفتن وأشراط الساعة", "الزهد والرقائق", "التفسير"]

for path, cid, name, names in ((sys.argv[1], "bukhari", "صحيح البخاري", BUKHARI), (sys.argv[2], "muslim", "صحيح مسلم", MUSLIM)):
    d = json.load(open(path, encoding="utf-8"))
    rows, counts = [], {}
    last = 0
    for h in sorted(d["hadiths"], key=lambda x: x["hadithnumber"]):
        b = h["reference"]["book"]
        # A few Bukhari entries have no book: they sit between hadiths of the same book, so take the previous one's.
        if b == 0 and cid == "bukhari":
            b = last
        last = b
        t = h["text"].strip()
        if not t:
            continue
        # Muslim: the common (Abdul-Baqi) number, e.g. 1907.01 -> 1907; Bukhari's numbers are already the common ones.
        num = int(float(h.get("arabicnumber") or h["hadithnumber"])) if cid == "muslim" else h["hadithnumber"]
        rows.append([b, num, t, matn_start(t)])
        counts[b] = counts.get(b, 0) + 1
    books = [[b, names[b]] for b in sorted(counts)]
    assert all(n for _, n in books), cid
    out = {"id": cid, "name": name, "books": books, "h": rows}
    data = gzip.compress(json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode(), 9)
    for dst in (f"mobile/assets/data/hadith_{cid}.json.gz", f"src/Mawaqeety.Core/Resources/hadith_{cid}.json.gz"):
        open(dst, "wb").write(data)
    print(cid, len(rows), "hadiths,", len(books), "books,", len(data) // 1024, "KB")
