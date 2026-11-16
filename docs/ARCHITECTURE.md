# البنية التقنية – Technical Architecture

## 1. اختيار التقنيات
| المجال | الاختيار | السبب |
|---|---|---|
| المنصة | **.NET 10 (LTS حتى 11/2028)** + C# | .NET 8 انتهى دعمه في 10/11/2026. |
| الواجهة | **WPF** | نضج عالٍ ودعم RTL كامل واستهلاك منخفض. يُبنى ويُختبر في CI حتى على غير Windows. لم نستخدم WinUI 3 لأنه يحتاج Windows App SDK runtime وتعقيد packaging أكبر لتطبيق tray بسيط. |
| MVVM | CommunityToolkit.Mvvm | Source generators ولا يحتاج reflection. |
| الإشعارات | CommunityToolkit.WinUI.Notifications | Toast أصلي لتطبيق غير مُحزّم (unpackaged)، مع أزرار ("إيقاف الصوت"). |
| شريط المهام | WinForms `NotifyIcon` | جزء من .NET نفسه ومستقر، ولا يحتاج مكتبة خارجية. |
| التخزين | SQLite (`Microsoft.Data.Sqlite`) | ملف واحد في `%AppData%\Mawaqeety`، ويدعم WAL. |
| السجلات | Serilog File (يومي، 14 يومًا، 5MB) | `%AppData%\Mawaqeety\logs`. |
| Excel / PDF | ClosedXML (MIT) / QuestPDF (Community) | ⚠️ ترخيص QuestPDF مجاني تحت مليون دولار إيرادات سنوية؛ راجعه قبل البيع. |
| التثبيت والتحديث | **Velopack** (Setup.exe) + سكربت Inno Setup بديل | تثبيت لكل مستخدم بدون صلاحيات المسؤول، واختصارات، وإزالة نظيفة، وتحديثات delta. |
| الخط | Cairo (SIL OFL) مضمّن | عربي واضح وحديث، ويُستخدم أيضًا في PDF. |

## 2. هيكل الحل
```
src/Mawaqeety.Core      (net10.0 – منطق نقي قابل للاختبار على أي نظام)
  Calculation/          محرك المواقيت الفلكي + جدول طرق الحساب
  Scheduling/           AlertPlanner (نقي) + AlertScheduler (الحلقة الخلفية) + PrayerStatus
  Services/             PrayerTimeService (محلي ← كاش أونلاين)، AladhanClient
  Data/                 AppDatabase (SQLite)، SettingsSerializer
  Geo/                  CityCatalog (284 مدينة/83 دولة دون إنترنت)، LocationSearchService (OSM + IP)
  Export/               ExcelExporter، PdfExporter
  Time/                 TimeZoneResolver (IANA/Windows/UTC±)، HijriDate (أم القرى + تعديل)
src/Mawaqeety.App       (net10.0-windows – WPF)
  Services/             Tray، Toast، Sound، AutoStart، SingleInstance، Theme، WindowsLocation، Update، FileLog
  ViewModels/ Views/    Dashboard، Monthly، Settings، About
  Localization/         Loc (عربي/إنجليزي وقت التشغيل) + {l:Tr Key}
tests/Mawaqeety.Tests   78 اختبار xUnit
tools/                  مولّدات بيانات المدن والأيقونة والصوت والمرجع الفلكي
installer/              build.ps1، build.sh، Mawaqeety.iss
```

## 3. محرك الحساب
- معادلات موقع الشمس القياسية (USNO / PrayTimes)، مع **3 تكرارات** لتحسين الدقة، وتقريب لأقرب دقيقة.
- يحسب في UTC ثم يحوّل عبر `TimeZoneInfo`، فـ**التوقيت الصيفي يُطبَّق تلقائيًا** حسب قواعد المنطقة الزمنية لكل تاريخ.
- أم القرى: العشاء بعد المغرب بـ 90 دقيقة، و120 دقيقة في رمضان.
- خطوط العرض العليا: AngleBased / OneSeventh / MiddleOfNight (تُطبَّق أيضًا عندما لا تبلغ الشمس الزاوية).
- التحقق: مقارنة مع مكتبة `astral` المستقلة (خوارزميات NOAA) لـ 7 مدن × 6 تواريخ بفارق ≤ 90 ثانية، وتحقق مستقل من ظل العصر.

## 4. قاعدة البيانات (SQLite)
| الجدول | الأعمدة الأساسية | الغرض |
|---|---|---|
| `settings` | key PK, value(JSON) | كل الإعدادات (نسخة schema داخل JSON). |
| `notification_log` | (local_date, prayer, kind) PK, status, logged_at | **منع التكرار**: `INSERT OR IGNORE` ذري قبل الإرسال، ويستمر بعد إعادة التشغيل. status = delivered/suppressed. |
| `prayer_cache` | (location_key, calc_key, local_date) PK, 6 أوقات ISO, source | مواقيت الإنترنت للعمل دون اتصال. |
| `recent_locations` | location_key PK, json, used_at | آخر 10 مواقع. |
| `schema_info` | version | للترقيات المستقبلية. |

التنظيف: سجل التنبيهات بعد 60 يومًا، والكاش بعد شهرين.

## 5. نظام التنبيهات
1. `AlertPlanner.Build` يولّد تنبيهات (قبل الوقت/عند الوقت) لأمس واليوم وغدًا حسب الإعدادات.
2. `AlertScheduler` ينام حتى أقرب تنبيه (بحد أقصى 30 ثانية)، ثم يقارن بالساعة الحقيقية. لذلك يتعافى ذاتيًا بعد السكون أو تغيير الساعة أو المنطقة. ويستيقظ فورًا عند `TimeChanged` و`PowerModeChanged.Resume` وتغيير الإعدادات.
3. نافذة سماح 15 دقيقة: إذا استيقظ الجهاز بعد دخول الوقت بقليل يصل التنبيه مرة واحدة، ويُتجاهل تذكير "قبل الصلاة" الذي فات.
4. الإيقاف المؤقت يسجّل التنبيهات كـ suppressed فلا تُعاد بعد الاستئناف.
5. الأوضاع: إشعار فقط / إشعار + صوت / صوت فقط / إيقاف، مع كتم عام يُبقي الإشعارات.

## 6. دورة حياة التطبيق
- `Program.Main` ← Velopack hooks ← Mutex للنسخة الواحدة (النسخة الثانية تطلب من الأولى إظهار نافذتها) ← `App`.
- `ShutdownMode=OnExplicitShutdown`: إغلاق النافذة يخفيها فقط، والإنهاء من قائمة شريط المهام.
- التشغيل التلقائي: `HKCU\...\Run` مع `--background`. يُزال عند إلغاء التثبيت.
- الأخطاء غير المعالجة تُسجَّل ولا توقف الخدمة الخلفية. قاعدة البيانات التالفة يُحتفظ بنسخة منها ثم تُنشأ من جديد.

## 7. الشبكة والخصوصية
كل الطلبات اختيارية، ولكلٍّ منها مهلة 15 ثانية، وفشلها لا يوقف البرنامج: Nominatim للبحث العالمي عن المدن، وAladhan للمصدر البديل والمنطقة الزمنية، وipwho.is لتحديد الموقع التقريبي عند تعذّر خدمة الموقع في Windows. لا تُرسل أي بيانات شخصية.
