using System.ComponentModel;
using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Markup;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.Localization;

/// <summary>
/// Runtime-switchable localization (Arabic / English). XAML binds through the indexer:
/// {l:Tr Key} → Binding [Key] on Loc.I, refreshed when the language changes.
/// </summary>
public sealed class Loc : INotifyPropertyChanged
{
    public static Loc I { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsArabic { get; private set; } = true;
    public FlowDirection FlowDirection => IsArabic ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public CultureInfo Culture => IsArabic ? ArabicCulture : CultureInfo.GetCultureInfo("en-US");

    /// <summary>Arabic culture with Gregorian calendar and Latin digits for times (clearer for clocks).</summary>
    private static readonly CultureInfo ArabicCulture = CreateArabic();

    private static CultureInfo CreateArabic()
    {
        var c = (CultureInfo)CultureInfo.GetCultureInfo("ar-EG").Clone();
        c.DateTimeFormat.Calendar = new GregorianCalendar(GregorianCalendarTypes.Localized);
        c.DateTimeFormat.AMDesignator = "ص";
        c.DateTimeFormat.PMDesignator = "م";
        return c;
    }

    public void SetLanguage(AppLanguage lang)
    {
        IsArabic = lang == AppLanguage.Arabic;
        Thread.CurrentThread.CurrentUICulture = Culture;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("Item[]"));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsArabic)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(FlowDirection)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Culture)));
        LanguageChanged?.Invoke(this, EventArgs.Empty);
    }

    public event EventHandler? LanguageChanged;

    public string this[string key] =>
        Strings.TryGetValue(key, out var v) ? (IsArabic ? v.Ar : v.En) : key;

    public static string T(string key) => I[key];

    public string Prayer(Prayer p) => this[p.ToString()];

    public string FormatTime(DateTimeOffset t, bool use24h) =>
        t.ToString(use24h ? "HH:mm" : "hh:mm tt", Culture);

    public string FormatCountdown(TimeSpan span)
    {
        if (span < TimeSpan.Zero) span = TimeSpan.Zero;
        return $"{(int)span.TotalHours:00}:{span.Minutes:00}:{span.Seconds:00}";
    }

    /// <summary>"2 h 15 min" / "ساعتان و15 دقيقة"-style short text for the tray tooltip.</summary>
    public string FormatRemainingShort(TimeSpan span)
    {
        if (span < TimeSpan.Zero) span = TimeSpan.Zero;
        var h = (int)span.TotalHours;
        var m = span.Minutes + (span.Seconds > 0 ? 1 : 0);
        if (m == 60) { h++; m = 0; }
        if (IsArabic)
            return h > 0 ? $"{h} س {m} د" : $"{m} دقيقة";
        return h > 0 ? $"{h}h {m}m" : $"{m} min";
    }

    private static readonly Dictionary<string, (string Ar, string En)> Strings = new()
    {
        ["AppName"] = ("مواقيتي", "Mawaqeety"),
        ["Slogan"] = ("صلاتك في وقتها", "Your prayer, on time"),
        // prayers
        ["Fajr"] = ("الفجر", "Fajr"),
        ["Sunrise"] = ("الشروق", "Sunrise"),
        ["Dhuhr"] = ("الظهر", "Dhuhr"),
        ["Asr"] = ("العصر", "Asr"),
        ["Maghrib"] = ("المغرب", "Maghrib"),
        ["Isha"] = ("العشاء", "Isha"),
        ["Friday"] = ("الجمعة", "Jumu'ah"),
        // navigation
        ["NavDashboard"] = ("الرئيسية", "Home"),
        ["NavMonthly"] = ("التقويم الشهري", "Monthly"),
        ["NavQuran"] = ("القرآن الكريم", "Qur'an"),
        ["NavProphets"] = ("قصص الأنبياء", "Prophets' stories"),
        ["NavAdhkar"] = ("الأذكار", "Adhkar"),
        ["NavQibla"] = ("القبلة", "Qibla"),
        ["Palette"] = ("ألوان الواجهة", "Colour style"),
        ["SecWidget"] = ("ويدجت سطح المكتب", "Desktop widget"),
        ["WidgetEnabled"] = ("إظهار نافذة صغيرة بالساعة والوقت المتبقي للصلاة", "Show a small window with the clock and time to the next prayer"),
        ["WidgetTopmost"] = ("تبقى فوق كل النوافذ", "Keep it above other windows"),
        ["WidgetHint"] = ("اسحبها بالماوس إلى المكان الذي تريده، وكليك يمين عليها لمزيد من الخيارات.", "Drag it anywhere; right-click it for more options."),
        ["TrayWidget"] = ("ويدجت سطح المكتب", "Desktop widget"),
        ["NavSettings"] = ("الإعدادات", "Settings"),
        ["NavAbout"] = ("حول البرنامج", "About"),
        // dashboard
        ["NextPrayer"] = ("الصلاة القادمة", "Next prayer"),
        ["TimeRemaining"] = ("الوقت المتبقي", "Time remaining"),
        ["CurrentPrayer"] = ("الوقت الحالي", "Current time"),
        ["CurrentPrayerTime"] = ("وقت صلاة {0}", "{0} time"),
        ["NoCurrentPrayer"] = ("لا توجد صلاة حاليًا (بعد الشروق)", "No prayer now (after sunrise)"),
        ["TodayTimes"] = ("مواقيت اليوم", "Today's prayer times"),
        ["Next"] = ("القادمة", "Next"),
        ["Now"] = ("الآن", "Now"),
        ["Passed"] = ("انتهت", "Passed"),
        ["AlertsPaused"] = ("التنبيهات متوقفة مؤقتًا حتى {0}", "Alerts paused until {0}"),
        ["Resume"] = ("استئناف", "Resume"),
        ["SourceLocal"] = ("محرك الحساب المحلي", "Local calculation engine"),
        ["SourceOnline"] = ("Aladhan (مخزنة محليًا)", "Aladhan (cached locally)"),
        ["Method"] = ("طريقة الحساب", "Calculation method"),
        ["ChangeLocation"] = ("تغيير الموقع", "Change location"),
        // tray
        ["TrayOpen"] = ("فتح مواقيتي", "Open Mawaqeety"),
        ["TrayPause"] = ("إيقاف التنبيهات مؤقتًا", "Pause alerts"),
        ["TrayPause30"] = ("30 دقيقة", "30 minutes"),
        ["TrayPause60"] = ("ساعة واحدة", "1 hour"),
        ["TrayPause180"] = ("3 ساعات", "3 hours"),
        ["TrayPauseTomorrow"] = ("حتى الغد", "Until tomorrow"),
        ["TrayResume"] = ("استئناف التنبيهات", "Resume alerts"),
        ["TrayStopSound"] = ("إيقاف الصوت", "Stop sound"),
        ["TrayExit"] = ("إنهاء البرنامج", "Exit"),
        ["TrayNext"] = ("{0} بعد {1}", "{0} in {1}"),
        ["TrayStillRunning"] = ("مواقيتي يعمل في الخلفية وسيذكّرك بمواعيد الصلاة.", "Mawaqeety keeps running in the background and will remind you of prayer times."),
        // notifications
        ["ToastAtTime"] = ("حان الآن موعد صلاة {0}", "It's time for {0} prayer"),
        ["ToastAtTimeSunrise"] = ("حان وقت الشروق", "Sunrise has started"),
        ["ToastPre"] = ("بقي {1} دقيقة على صلاة {0}", "{1} minutes until {0}"),
        ["ToastPreSunrise"] = ("بقي {1} دقيقة على الشروق", "{1} minutes until sunrise"),
        ["ToastBody"] = ("{0} • {1}", "{0} • {1}"),
        ["ToastStopSound"] = ("إيقاف الصوت", "Stop sound"),
        ["ToastDismiss"] = ("إغلاق", "Dismiss"),
        // monthly
        ["Date"] = ("التاريخ", "Date"),
        ["Day"] = ("اليوم", "Day"),
        ["Hijri"] = ("الهجري", "Hijri"),
        ["ExportExcel"] = ("تصدير Excel", "Export Excel"),
        ["ExportPdf"] = ("تصدير PDF", "Export PDF"),
        ["PrevMonth"] = ("الشهر السابق", "Previous month"),
        ["NextMonth"] = ("الشهر التالي", "Next month"),
        ["ThisMonth"] = ("الشهر الحالي", "This month"),
        ["MonthlyTitle"] = ("مواقيت الصلاة - {0}", "Prayer times - {0}"),
        ["ExportDone"] = ("تم حفظ الملف بنجاح.", "File saved successfully."),
        ["ExportFailed"] = ("تعذر حفظ الملف: {0}", "Could not save the file: {0}"),
        ["OpenFile"] = ("فتح الملف", "Open file"),
        // settings
        ["SecLocation"] = ("الموقع", "Location"),
        ["SecCalculation"] = ("طريقة الحساب", "Calculation"),
        ["SecAlerts"] = ("التنبيهات", "Alerts"),
        ["SecPerPrayer"] = ("إعدادات كل صلاة", "Per-prayer settings"),
        ["SecAppearance"] = ("المظهر واللغة", "Appearance & language"),
        ["SecSystem"] = ("النظام", "System"),
        ["SearchCity"] = ("ابحث عن مدينة أو دولة...", "Search city or country..."),
        ["SearchOnline"] = ("بحث عالمي (إنترنت)", "Worldwide search (online)"),
        ["DetectLocation"] = ("تحديد موقعي تلقائيًا", "Detect my location"),
        ["Detecting"] = ("جارٍ تحديد الموقع...", "Detecting location..."),
        ["DetectFailed"] = ("تعذر تحديد الموقع. تأكد من تفعيل خدمات الموقع في Windows أو اختر المدينة يدويًا.", "Could not detect location. Enable Windows location services or pick a city manually."),
        ["Searching"] = ("جارٍ البحث...", "Searching..."),
        ["NoResults"] = ("لا توجد نتائج. جرّب البحث العالمي.", "No results. Try worldwide search."),
        ["CurrentLocation"] = ("الموقع الحالي", "Current location"),
        ["Latitude"] = ("خط العرض", "Latitude"),
        ["Longitude"] = ("خط الطول", "Longitude"),
        ["ManualCoordinates"] = ("إحداثيات يدوية", "Manual coordinates"),
        ["Apply"] = ("تطبيق", "Apply"),
        ["TimeZone"] = ("المنطقة الزمنية", "Time zone"),
        ["AutoTimeZone"] = ("ضبط المنطقة الزمنية والتوقيت الصيفي تلقائيًا", "Automatic time zone & daylight saving"),
        ["ManualOffset"] = ("فرق التوقيت عن UTC (بالدقائق)", "UTC offset (minutes)"),
        ["ManualDst"] = ("إضافة ساعة للتوقيت الصيفي", "Add one hour (summer time)"),
        ["Madhab"] = ("المذهب في حساب العصر", "Asr juristic method"),
        ["Shafii"] = ("الجمهور (الشافعي، المالكي، الحنبلي)", "Standard (Shafi'i, Maliki, Hanbali)"),
        ["Hanafi"] = ("الحنفي", "Hanafi"),
        ["HighLat"] = ("خطوط العرض العليا", "High-latitude rule"),
        ["HL_None"] = ("بدون", "None"),
        ["HL_AngleBased"] = ("حسب الزاوية (موصى به)", "Angle-based (recommended)"),
        ["HL_OneSeventh"] = ("سُبع الليل", "One-seventh of the night"),
        ["HL_MiddleOfNight"] = ("منتصف الليل", "Middle of the night"),
        ["CustomFajr"] = ("زاوية الفجر", "Fajr angle"),
        ["CustomIsha"] = ("زاوية العشاء", "Isha angle"),
        ["Source"] = ("مصدر المواقيت", "Times source"),
        ["Src_Local"] = ("محرك محلي فقط (يعمل دون إنترنت)", "Local engine only (works offline)"),
        ["Src_OnlineWithLocalFallback"] = ("Aladhan عبر الإنترنت + المحرك المحلي احتياطيًا", "Aladhan online + local fallback"),
        ["SyncNow"] = ("مزامنة الآن", "Sync now"),
        ["SyncOk"] = ("تمت المزامنة وحفظ المواقيت للعمل دون إنترنت.", "Synced and saved for offline use."),
        ["SyncFailed"] = ("تعذرت المزامنة، سيتم استخدام المحرك المحلي.", "Sync failed; the local engine will be used."),
        ["HijriAdjust"] = ("تعديل التاريخ الهجري (أيام)", "Hijri date adjustment (days)"),
        ["SecAdhan"] = ("الأذان", "Adhan"),
        ["AdhanEnabled"] = ("تشغيل الأذان بصوت المؤذن عند دخول وقت الصلاة", "Play the adhan when the prayer time starts"),
        ["AdhanVoice"] = ("صوت الأذان", "Adhan voice"),
        ["FajrAdhanVoice"] = ("أذان الفجر", "Fajr adhan"),
        ["Preview"] = ("استماع", "Listen"),
        ["StopPreview"] = ("إيقاف", "Stop"),
        ["AdhanReady"] = ("✓ جاهز ويعمل دون إنترنت", "✓ Ready (works offline)"),
        ["AdhanDownloading"] = ("جارٍ تحميل الأذان...", "Downloading adhan..."),
        ["AdhanPending"] = ("سيُحمَّل تلقائيًا عند توفر الإنترنت (تُستخدم النغمة مؤقتًا)", "Will download automatically when online (chime used meanwhile)"),
        ["AdhanFailed"] = ("تعذّر التحميل. تأكد من الاتصال بالإنترنت.", "Download failed. Check your internet connection."),
        ["AdhanNote"] = ("يُشغَّل الأذان للصلوات الخمس عند دخول الوقت فقط. التذكير قبل الصلاة يستخدم نغمة قصيرة. يمكنك إيقاف الأذان في أي وقت من زر \"إيقاف الصوت\" في الإشعار أو شريط المهام.",
                         "The adhan plays only when each of the five prayers starts; reminders use a short chime. Stop it anytime from the notification or the tray menu."),
        ["SoundAdhan"] = ("الأذان: {0}", "Adhan: {0}"),
        ["PreAlert"] = ("تنبيه قبل الصلاة", "Reminder before prayer"),
        ["PreAlertMinutes"] = ("قبل الصلاة بـ", "Minutes before"),
        ["Minutes"] = ("دقيقة", "minutes"),
        ["Custom"] = ("مخصص", "Custom"),
        ["PreAlertMode"] = ("نوع تنبيه التذكير", "Reminder type"),
        ["MuteAll"] = ("كتم جميع الأصوات (مع إبقاء الإشعارات)", "Mute all sounds (keep notifications)"),
        ["Volume"] = ("مستوى الصوت", "Volume"),
        ["Mode_NotificationOnly"] = ("إشعار فقط", "Notification only"),
        ["Mode_NotificationWithSound"] = ("إشعار مع صوت", "Notification + sound"),
        ["Mode_SoundOnly"] = ("صوت فقط", "Sound only"),
        ["Mode_Off"] = ("إيقاف", "Off"),
        ["Enabled"] = ("مفعّل", "Enabled"),
        ["AlertType"] = ("نوع التنبيه", "Alert type"),
        ["Sound"] = ("الصوت", "Sound"),
        ["DefaultSound"] = ("النغمة الافتراضية", "Default chime"),
        ["Browse"] = ("اختيار ملف...", "Choose file..."),
        ["Test"] = ("تجربة", "Test"),
        ["Reset"] = ("افتراضي", "Default"),
        ["Adjustment"] = ("تعديل (دقائق)", "Adjust (min)"),
        ["Theme"] = ("المظهر", "Theme"),
        ["Theme_Dark"] = ("ليلي", "Dark"),
        ["Theme_Light"] = ("نهاري", "Light"),
        ["Theme_System"] = ("حسب Windows", "Follow Windows"),
        ["Language"] = ("اللغة", "Language"),
        ["Clock24"] = ("نظام 24 ساعة", "24-hour clock"),
        ["StartWithWindows"] = ("تشغيل البرنامج تلقائيًا مع Windows", "Start with Windows"),
        ["StartMinimized"] = ("البدء في الخلفية (شريط المهام)", "Start in the background (tray)"),
        ["CloseToTray"] = ("الإغلاق يُبقي البرنامج يعمل في الخلفية", "Closing the window keeps running in the tray"),
        ["TestNotification"] = ("إرسال إشعار تجريبي", "Send test notification"),
        ["OpenLogs"] = ("فتح مجلد السجلات", "Open logs folder"),
        ["Saved"] = ("تم الحفظ", "Saved"),
        // about
        ["Version"] = ("الإصدار", "Version"),
        ["CheckUpdates"] = ("البحث عن تحديثات", "Check for updates"),
        ["UpToDate"] = ("أنت تستخدم أحدث إصدار.", "You're on the latest version."),
        ["UpdateAvailable"] = ("يتوفر إصدار جديد {0}. سيتم تثبيته وإعادة تشغيل البرنامج.", "Version {0} is available. It will be installed and the app restarted."),
        ["UpdatesNotConfigured"] = ("التحديث التلقائي متاح عند التثبيت عبر ملف Setup.", "Automatic updates are available when installed via Setup."),
        ["UpdateFailed"] = ("تعذر التحقق من التحديثات.", "Could not check for updates."),
        ["AboutText"] = ("برنامج لعرض مواقيت الصلاة والتذكير بها تلقائيًا. يحسب المواقيت محليًا بدقة فلكية ويعمل دون اتصال بالإنترنت.",
                         "Shows prayer times and reminds you automatically. Times are calculated locally with astronomical precision and work offline."),
        ["Credits"] = ("بيانات المدن: OpenStreetMap • مصدر بديل: Aladhan API • الخط: Cairo (OFL)", "City search: OpenStreetMap • Optional source: Aladhan API • Font: Cairo (OFL)"),
        ["Notice"] = ("ننصح بمطابقة المواقيت مع الجهة الرسمية في بلدك واستخدام تعديل الدقائق عند الحاجة.", "We recommend comparing with your local official timetable and using minute adjustments if needed."),
        ["SoundFiles"] = ("ملفات صوت", "Audio files"),
        ["Error"] = ("خطأ", "Error"),
        ["Ok"] = ("حسنًا", "OK"),
    };
}

/// <summary>XAML: Text="{l:Tr NextPrayer}"</summary>
[MarkupExtensionReturnType(typeof(object))]
public sealed class TrExtension : MarkupExtension
{
    public TrExtension() { }
    public TrExtension(string key) => Key = key;

    [ConstructorArgument("key")]
    public string Key { get; set; } = "";

    public override object ProvideValue(IServiceProvider serviceProvider) =>
        new Binding($"[{Key}]") { Source = Loc.I, Mode = BindingMode.OneWay }.ProvideValue(serviceProvider);
}
