/// Islamic occasions by Hijri date, with the sahih hadith about each (numbers checked against the bundled
/// Sahih al-Bukhari and Sahih Muslim).
enum OccasionKind { fast, event, season, noFast }

class Occasion {
  final String id, name, note, ref;
  final int month, day, days; // days: how many days it lasts
  final OccasionKind kind;
  const Occasion(this.id, this.month, this.day, this.name, this.kind, {this.days = 1, this.note = '', this.ref = ''});
  bool get isFast => kind == OccasionKind.fast;
}

const occasions = <Occasion>[
  Occasion('newyear', 1, 1, 'رأس السنة الهجرية', OccasionKind.event, note: 'بداية عام هجري جديد'),
  Occasion('tasua', 1, 9, 'صيام تاسوعاء', OccasionKind.fast,
      note: '«لئن بقيتُ إلى قابلٍ لأصومنّ التاسع»', ref: 'صحيح مسلم ١١٣٤'),
  Occasion('ashura', 1, 10, 'صيام عاشوراء', OccasionKind.fast,
      note: '«صيام يوم عاشوراء أحتسب على الله أن يكفّر السنة التي قبله»', ref: 'صحيح مسلم ١١٦٢'),
  Occasion('ramadan', 9, 1, 'بداية شهر رمضان', OccasionKind.event, days: 30, note: 'شهر الصيام والقيام والقرآن'),
  Occasion('lastten', 9, 21, 'العشر الأواخر وليلة القدر', OccasionKind.season, days: 10,
      note: '«تحرّوا ليلة القدر في الوتر من العشر الأواخر من رمضان»', ref: 'صحيح البخاري ٢٠١٧'),
  Occasion('fitr', 10, 1, 'عيد الفطر', OccasionKind.noFast,
      note: 'نهى النبي ﷺ عن صيام يوم الفطر ويوم الأضحى', ref: 'صحيح مسلم ١١٣٨'),
  Occasion('shawwal', 10, 2, 'ستٌّ من شوال', OccasionKind.fast, days: 28,
      note: '«من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر»', ref: 'صحيح مسلم ١١٦٤'),
  Occasion('dhulhijja', 12, 1, 'العشر من ذي الحجة', OccasionKind.season, days: 10,
      note: '«ما العمل في أيامٍ العشر أفضل من العمل في هذه»', ref: 'صحيح البخاري ٩٦٩'),
  Occasion('arafah', 12, 9, 'صيام يوم عرفة', OccasionKind.fast,
      note: '«صيام يوم عرفة أحتسب على الله أن يكفّر السنة التي قبله والسنة التي بعده»', ref: 'صحيح مسلم ١١٦٢'),
  Occasion('adha', 12, 10, 'عيد الأضحى', OccasionKind.noFast,
      note: 'نهى النبي ﷺ عن صيام يوم الفطر ويوم الأضحى', ref: 'صحيح مسلم ١١٣٨'),
  Occasion('tashreeq', 12, 11, 'أيام التشريق', OccasionKind.noFast, days: 3,
      note: '«أيام التشريق أيام أكلٍ وشرب»', ref: 'صحيح مسلم ١١٤١'),
];

const monThuNote = 'سُئل ﷺ عن صوم يوم الاثنين فقال: «ذاك يومٌ وُلدتُ فيه، ويومٌ بُعثتُ أو أُنزل عليّ فيه»';
const monThuRef = 'صحيح مسلم ١١٦٢';
