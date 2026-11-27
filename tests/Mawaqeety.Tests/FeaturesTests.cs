using System.Text.Json.Nodes;
using Mawaqeety.Core;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Data;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.Tests;

/// <summary>«اسأل سبيل»: the cases of the mobile app's test/sabeel_test.dart, plus a few more.</summary>
public class SabeelTests
{
    private static readonly Sabeel S = Sabeel.Default;

    [Fact]
    public void Named_ayah()
    {
        var a = S.Ask("تفسير آية الكرسي");
        var x = Assert.Single(a.Ayat);
        Assert.Equal((2, 255), (x.Surah.Number, x.Ayah));
        Assert.Contains("آية الكرسي", x.Tafsir);
        Assert.Equal("سورة البقرة — الآية ٢٥٥", a.Title);
    }

    [Fact]
    public void Surah_and_number()
    {
        var a = Assert.Single(S.Ask("سورة الكهف آية ١٠").Ayat);
        Assert.Equal((18, 10), (a.Surah.Number, a.Ayah));
        Assert.Equal(255, Assert.Single(S.Ask("2:255").Ayat).Ayah);
        Assert.Equal(2, S.Ask("البقرة 285 - 286").Ayat.Count);
        Assert.Equal(10, Assert.Single(S.Ask("الكهف 10").Ayat).Ayah);
        Assert.Equal([285, 286], S.Ask("خواتيم البقرة").Ayat.Select(x => x.Ayah));
    }

    [Fact]
    public void Keywords_hadith_and_ruling()
    {
        Assert.NotEmpty(S.Ask("الصبر").Ayat);
        Assert.NotEmpty(S.Ask("الصبر").Hadith);
        Assert.NotEmpty(S.Ask("حديث إنما الأعمال بالنيات").Hadith);
        Assert.True(S.Ask("ما حكم الربا").Ruling);
        Assert.False(S.Ask("الصبر").Ruling);
        Assert.NotEmpty(S.Ask("بر الوالدين").Ayat);
        Assert.True(S.Ask("xyz").IsEmpty);
        Assert.True(S.Ask("").IsEmpty);
    }

    [Fact]
    public void Whole_surah_and_ranges_are_limited()
    {
        var mulk = S.Ask("سورة الملك");
        Assert.Equal(10, mulk.Ayat.Count);
        Assert.True(mulk.More);
        Assert.All(mulk.Ayat, x => Assert.Equal(67, x.Surah.Number));
        Assert.Equal(10, S.Ask("2:1-40").Ayat.Count);
        Assert.True(S.Ask("2:999").IsEmpty || S.Ask("2:999").Ayat.All(x => x.Surah.Number != 2 || x.Ayah <= 286));
    }

    [Fact]
    public void Word_start_matching_and_stems()
    {
        Assert.Equal("صبر", Sabeel.Stem("والصبر"));
        Assert.Equal("صبر", Sabeel.Stem("بالصبر"));
        Assert.True(Sabeel.Has("والصبر خير", "صبر"));
        Assert.True(Sabeel.Has("الذين صبروا", "صبر"));
        Assert.False(Sabeel.Has("اقربايكم", "ربا"));
        Assert.True(Sabeel.Has("ليس البر ان", "بر"));
        Assert.False(Sabeel.Has("البراءه", "بر"));
    }
}

public class HijriAndOccasionTests
{
    [Fact]
    public void Hijri_to_gregorian_inverts_from()
    {
        foreach (var adj in new[] { -1, 0, 1 })
            for (var d = new DateOnly(2025, 1, 1); d < new DateOnly(2027, 1, 1); d = d.AddDays(13))
            {
                var h = HijriDate.From(d, adj);
                Assert.Equal(d, HijriDate.ToGregorian(h.Year, h.Month, h.Day, adj));
            }
        Assert.Equal(new DateOnly(2026, 2, 18), HijriDate.ToGregorian(1447, 9, 1)); // Ramadan 1447 (Umm al-Qura)
        Assert.InRange(HijriDate.DaysInMonth(1447, 9), 29, 30);
        Assert.Equal("رمضان", HijriDate.MonthNameAr(9));
        // day 30 of a 29-day month is the next month's first day
        var m = Enumerable.Range(1, 12).First(x => HijriDate.DaysInMonth(1447, x) == 29);
        Assert.Equal(HijriDate.ToGregorian(1447, m + 1, 1), HijriDate.ToGregorian(1447, m, 30));
    }

    [Fact]
    public void Next_occasion_and_sunnah_fasts()
    {
        var arafah = Occasions.All.Single(o => o.Id == "arafah");
        var from = new DateOnly(2026, 11, 27);
        var next = Occasions.Next(arafah, from);
        Assert.True(next >= from);
        Assert.Equal((12, 9), (HijriDate.From(next).Month, HijriDate.From(next).Day));
        // A season that has started is still "now".
        var ramadan = Occasions.All.Single(o => o.Id == "ramadan");
        var mid = HijriDate.ToGregorian(1447, 9, 15);
        Assert.Equal(HijriDate.ToGregorian(1447, 9, 1), Occasions.Next(ramadan, mid));

        Assert.Equal("صيام يوم عرفة", Occasions.SunnahFastOn(next));
        Assert.Equal("الأيام البيض", Occasions.SunnahFastOn(HijriDate.ToGregorian(1448, 5, 14)));
        Assert.Equal("ستٌّ من شوال", Occasions.SunnahFastOn(HijriDate.ToGregorian(1447, 10, 5)));
        // Ramadan: no voluntary fast suggested, even on a Monday
        var monInRamadan = Enumerable.Range(0, 29).Select(i => HijriDate.ToGregorian(1447, 9, 1).AddDays(i)).First(d => d.DayOfWeek == DayOfWeek.Monday);
        Assert.Null(Occasions.SunnahFastOn(monInRamadan));
        Assert.Equal("بعد ٥ أيام", Occasions.InDays(5));
        Assert.Equal("غدًا", Occasions.InDays(1));
        Assert.Equal("صفحتان", Occasions.Pages(2));
        Assert.Equal("٢٠ ليلة", Occasions.Nights(20));
    }

    [Fact]
    public void Ninety_nine_names()
    {
        Assert.Equal(99, AsmaAlHusna.All.Count);
        Assert.Equal("الله", AsmaAlHusna.All[0].Name);
        Assert.Equal("الصبور", AsmaAlHusna.All[98].Name);
        Assert.Equal(18, AsmaAlHusna.All.Count(n => n.Disputed));
        Assert.InRange(AsmaAlHusna.OfDay(new DateOnly(2026, 11, 27)), 0, 98);
        Assert.NotEqual(AsmaAlHusna.OfDay(new DateOnly(2026, 11, 27)), AsmaAlHusna.OfDay(new DateOnly(2026, 11, 28)));
    }
}

public class KhatmaZakatBackupTests
{
    private static string TempFile() => Path.Combine(Path.GetTempPath(), "mawaqeety-test-" + Guid.NewGuid() + ".json");

    [Fact]
    public void Khatma_plan_progress_and_completion()
    {
        var s = new AppSettings();
        var today = new DateOnly(2026, 11, 27);
        Assert.Equal(0, Khatma.Daily(s));
        Khatma.Start(s, 30, today);
        Assert.Equal(21, Khatma.Daily(s));
        Assert.Equal(21, Khatma.Target(s, today));
        Assert.Equal(42, Khatma.Target(s, today.AddDays(1)));
        Assert.Equal(1, Khatma.NotePage(s, today, 1));
        Assert.Equal(1, Khatma.NotePage(s, today, 1));
        Assert.False(Khatma.WouldChange(s, today, 1));
        Assert.Equal(2, Khatma.NotePage(s, today, 2));
        Assert.Equal(2, s.KhatmaPage);
        Assert.Equal(19, Khatma.Behind(s, today));
        // a new day starts a new count
        Assert.Equal(0, Khatma.PagesToday(s, today.AddDays(1)));
        Assert.Equal(1, Khatma.NotePage(s, today.AddDays(1), 3));
        // jumping to the last page does not complete the khatma
        Khatma.NotePage(s, today.AddDays(1), 604);
        Assert.Equal(0, s.KhatmaDone);
        Assert.Equal(604, s.KhatmaPage);
        // reading in order to the end does
        s.KhatmaPage = 580;
        Khatma.NotePage(s, today.AddDays(2), 600);
        Khatma.NotePage(s, today.AddDays(2), 604);
        Assert.Equal(1, s.KhatmaDone);
        Assert.Equal(0, s.KhatmaPage);
        Assert.Equal(Khatma.Key(today.AddDays(2)), s.KhatmaStart);
        Assert.Equal("أسبوع", Khatma.PlanLabel(7));
        Assert.Equal(87, Khatma.DailyFor(7));
        Khatma.Stop(s);
        Assert.Equal(0, s.KhatmaDays);
    }

    [Fact]
    public void Zakat_nisab_and_karats()
    {
        var r = Zakat.Compute(new Zakat.Input(Cash: 100_000), goldPrice: 4000, silverPrice: 50, bySilver: false);
        Assert.Equal(340_000, r.Nisab);
        Assert.False(r.Due);
        r = Zakat.Compute(new Zakat.Input(Cash: 300_000, Gold21: 24, Debts: 10_000), 4000, 50, false);
        Assert.Equal(300_000 + 21 * 4000 - 10_000, r.Total, 3);
        Assert.True(r.Due);
        Assert.Equal(r.Total * 0.025, r.Amount, 3);
        r = Zakat.Compute(new Zakat.Input(Cash: 100_000), 4000, 50, bySilver: true);
        Assert.Equal(29_750, r.Nisab);
        Assert.True(r.Due);
        Assert.False(Zakat.Compute(new Zakat.Input(Cash: 5), 0, 0, false).PricesKnown);
        Assert.Equal(1250.5, Zakat.Parse("١٬٢٥٠٫٥"));
        Assert.Equal(1250.5, Zakat.Parse("1,250.5"));
        Assert.Equal("١٢,٣٤٥.٦٧", Zakat.Money(12345.67));
    }

    [Fact]
    public void Tracker_keeps_the_mobile_keys()
    {
        var f = TempFile();
        try
        {
            var t = new Tracker(f);
            var d = new DateOnly(2026, 3, 1);
            t.SetFast(d, true);
            t.SetTaraweeh(d, 8);
            t.SetTahajjud(d, true);
            t.SetSunnah(d, Sunnah.Fajr, true);
            t.SetSunnah(d, Sunnah.Witr, true);
            t.SetPages(d, 5);
            t.SetPrayer(d, Prayer.Isha, PrayerLog.Mosque);
            var o = JsonNode.Parse(File.ReadAllText(f))!["2026-03-01"]!.AsObject();
            Assert.Equal(1, (int)o["f"]!);
            Assert.Equal(8, (int)o["tr"]!);
            Assert.Equal(1, (int)o["q"]!);
            Assert.Equal(1 | 32, (int)o["sn"]!);
            Assert.Equal(5, (int)o["qp"]!);
            Assert.Equal(1, (int)o["p"]!["isha"]!);

            var again = new Tracker(f).Day(d);
            Assert.True(again.Fast && again.Tahajjud);
            Assert.Equal(8, again.Taraweeh);
            Assert.Equal(2, again.SunanDone);
            Assert.True(again.Did(Sunnah.Witr));
            Assert.False(again.Did(Sunnah.Duha));
            Assert.Equal(5, again.Pages);

            t.SetSunnah(d, Sunnah.Fajr, false);
            Assert.Equal(32, t.Day(d).Sunan);
        }
        finally { File.Delete(f); }
    }

    [Fact]
    public void Backup_round_trip_and_mobile_file()
    {
        var f1 = TempFile();
        var f2 = TempFile();
        try
        {
            var t = new Tracker(f1);
            t.SetFast(new DateOnly(2026, 3, 2), true);
            t.SetPrayer(new DateOnly(2026, 3, 2), Prayer.Fajr, PrayerLog.Jamaah);
            var s = new AppSettings { KhatmaDays = 20, GoldPrice = 3500, Palette = "mocha" };
            var text = Backup.Export(s, t);
            var j = JsonNode.Parse(text)!;
            Assert.Equal("sabeel", (string)j["app"]!);
            Assert.Equal(1, (int)j["version"]!);
            Assert.Equal(1, (int)j["tracker"]!["2026-03-02"]!["f"]!);

            var r = Backup.Parse(text, new AppSettings())!;
            Assert.Equal(20, r.Settings!.KhatmaDays);
            Assert.Equal("mocha", r.Settings.Palette);
            var t2 = new Tracker(f2);
            t2.ImportJson(r.Tracker);
            Assert.True(t2.Day(new DateOnly(2026, 3, 2)).Fast);
            Assert.Equal(PrayerLog.Jamaah, t2.Day(new DateOnly(2026, 3, 2)).Of(Prayer.Fajr));

            // A backup made on the phone: its tracker and the shared settings.
            const string mobile = """
                {"app":"sabeel","version":1,"date":"2026-11-27T10:00:00.000","settings":{"palette":"latte","khatmaDays":30,"khatmaPage":42,
                 "khatmaStart":"2026-11-20","goldPrice":4100.5,"nisabSilver":true,"theme":"dark","place":{"nameAr":"x","lat":1,"lng":2}},
                 "tracker":{"2026-11-26":{"p":{"fajr":1,"asr":3},"m":1,"t":33,"f":1,"tr":11,"q":1,"sn":63,"qp":4}}}
                """;
            var m = Backup.Parse(mobile, new AppSettings { Location = GeoLocation.Cairo })!;
            Assert.Equal("latte", m.Settings!.Palette);
            Assert.Equal(30, m.Settings.KhatmaDays);
            Assert.Equal(42, m.Settings.KhatmaPage);
            Assert.Equal(4100.5, m.Settings.GoldPrice);
            Assert.True(m.Settings.NisabSilver);
            t2.ImportJson(m.Tracker);
            var day = t2.Day(new DateOnly(2026, 11, 26));
            Assert.Equal(6, day.SunanDone);
            Assert.Equal(11, day.Taraweeh);
            Assert.Equal(4, day.Pages);
            Assert.Equal(PrayerLog.Alone, day.Of(Prayer.Asr));
            Assert.True(t2.Day(new DateOnly(2026, 3, 2)).IsEmpty); // replaced, not merged
            Assert.Equal(JsonNode.Parse(mobile)!["tracker"]!.ToJsonString(), t2.ExportJson());

            Assert.Null(Backup.Parse("{\"app\":\"other\",\"settings\":{}}", new AppSettings()));
            Assert.Null(Backup.Parse("not json", new AppSettings()));
        }
        finally { File.Delete(f1); File.Delete(f2); }
    }
}
