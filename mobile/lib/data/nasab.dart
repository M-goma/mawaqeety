/// النسب الشريف: the Prophet's ﷺ lineage up to عدنان (the part agreed on by the genealogists), with short
/// notes from Ibn Hajr's commentary, and where the lineage of each of the ten promised Paradise meets it.
///
/// Every note and meeting point comes from a page that was opened and read (see [NasabSource.url]).
library;

class NasabSource {
  final String label, url;
  const NasabSource(this.label, this.url);
}

/// One ancestor in the chain. [note] is a short, sourced remark (null when nothing reliable is worth saying).
class Ancestor {
  final String name;
  final String? note;
  const Ancestor(this.name, [this.note]);
}

/// A companion's own lineage, from himself up to (and including) the ancestor he shares with the Prophet ﷺ.
class CompanionNasab {
  final String id, name, clan;

  /// Names from the companion up to the meeting ancestor (last element).
  final List<String> chain;

  /// Index of the meeting ancestor in [Nasab.chain].
  final int meet;
  final String? remark;
  final NasabSource source;
  const CompanionNasab(this.id, this.name, this.clan, this.chain, this.meet, this.source, [this.remark]);
  String get meetName => chain.last;

  /// «أبو بكر بن ... بن مرة».
  String get lineage => chain.join(' بن ');
}

class Nasab {
  static const fath = NasabSource('فتح الباري لابن حجر، شرح باب مبعث النبي ﷺ', 'https://www.islamweb.net/ar/library/content/52/6996/');
  static const bukhariRef = 'صحيح البخاري، كتاب مناقب الأنصار، باب مبعث النبي ﷺ (ترجمة الباب قبل الحديث ٣٨٥١)';
  static const zad = NasabSource(
    'ابن القيم، زاد المعاد (منقول في مقال «النسب النبوي الشريف» – إسلام ويب)',
    'https://www.islamweb.net/ar/article/220978/',
  );
  static const motherSource = NasabSource('إسلام ويب، الفتوى ٢٣٩٥٨', 'https://www.islamweb.net/ar/fatwa/23958/');

  static const intro =
      'هو محمد بن عبد الله بن عبد المطلب بن هاشم بن عبد مناف بن قصي بن كلاب بن مرة بن كعب بن لؤي بن غالب بن فهر بن مالك بن النضر بن كنانة بن خزيمة بن مدركة بن إلياس بن مضر بن نزار بن معد بن عدنان ﷺ.';
  static const agreed =
      'قال ابن القيم: «إلى هاهنا معلوم الصحة متفق عليه بين النسّابين، ولا خلاف فيه البتة، وما فوق عدنان مختلف فيه، ولا خلاف بينهم أن عدنان من ولد إسماعيل عليه السلام».';
  static const mother =
      'أمه ﷺ آمنة بنت وهب بن عبد مناف بن زهرة بن كلاب بن مرة؛ فيلتقي نسبه من جهة أمه بنسبه من جهة أبيه عند كلاب بن مرة: '
      'أبوه من ولد قصي بن كلاب، وأمه من ولد زهرة بن كلاب. ولهذا كان بنو زهرة أخوال النبي ﷺ.';

  /// From the Prophet ﷺ (index 0) up to عدنان (index 20), exactly as in the heading of the chapter in al-Bukhari.
  static const chain = <Ancestor>[
    Ancestor(
      'محمد ﷺ',
      'قال ابن عباس: أُنزل عليه وهو ابن أربعين، فمكث ثلاث عشرة سنة، ثم أُمر بالهجرة فهاجر إلى المدينة فمكث بها عشر سنين، ثم توفي ﷺ (صحيح البخاري ٣٨٥١).',
    ),
    Ancestor('عبد الله', 'أبوه ﷺ، لم يُختلف في اسمه، ومات قبل أن يولد النبي ﷺ على الأثبت، وقيل بعد ولادته.'),
    Ancestor(
      'عبد المطلب',
      'اسمه شيبة الحمد عند الجمهور، وغلب عليه «عبد المطلب» لأن عمه المطلب قدم به مكة مُردَفًا خلفه، فقالوا: هذا عبد المطلب.',
    ),
    Ancestor('هاشم', 'اسمه عمرو، وسُمّي هاشمًا لأنه أول من هشم الثريد لأهل الموسم ولقومه في سنة المجاعة.'),
    Ancestor('عبد مناف', 'اسمه المغيرة، كما نقل أحمد عن الشافعي.'),
    Ancestor('قصي', 'اسمه زيد، ولُقّب قصيًّا لأنه بَعُد عن ديار قومه في بلاد قضاعة.'),
    Ancestor('كلاب', 'عنده يلتقي نسب النبي ﷺ من جهة أبيه ومن جهة أمه آمنة بنت وهب بن عبد مناف بن زهرة بن كلاب.'),
    Ancestor('مرة', 'قال السهيلي: منقول من وصف الحنظلة، والمراد أنه قوي.'),
    Ancestor(
      'كعب',
      'قيل: سُمّي بذلك لارتفاعه على قومه وشرفه فيهم، حتى أرّخوا بموته، وهو أول من جمع قومه يوم الجمعة، وكانوا يسمونه يوم العروبة.',
    ),
    Ancestor('لؤي', 'قيل: تصغير «لأي» وهو البطء، وقيل غير ذلك.'),
    Ancestor('غالب'),
    Ancestor('فهر', 'قيل: هو قريش، نقل الزبير بن بكار عن الزهري أن أمه سمّته قريشًا وسمّاه أبوه فهرًا، وقيل غير ذلك.'),
    Ancestor('مالك'),
    Ancestor('النضر'),
    Ancestor('كنانة', 'بلفظ وعاء السهام، وذُكر أنه كان شيخًا عظيم القدر تحج إليه العرب لعلمه وفضله بينهم.'),
    Ancestor('خزيمة', 'تصغير «خزمة»، من الخزم وهو شدّ الشيء وإصلاحه.'),
    Ancestor('مدركة', 'اسمه عمرو عند الجمهور، وقال ابن إسحاق: عامر.'),
    Ancestor('إلياس', 'قيل: من «الأليس» وهو الشجاع الذي لا يفرّ.'),
    Ancestor('مضر', 'قيل: سُمّي بذلك لبياضه، وقيل غير ذلك.'),
    Ancestor('نزار', 'من النزر أي القليل، قيل: لأنه كان فريد عصره.'),
    Ancestor('معد'),
    Ancestor(
      'عدنان',
      'إلى عدنان اقتصر البخاري، وهو القدر المتفق عليه بين النسّابين، وما فوقه مختلف فيه، ولا خلاف أن عدنان من ولد إسماعيل عليه السلام.',
    ),
  ];

  static int indexOf(String name) => chain.indexWhere((a) => a.name == name);

  static const companions = <CompanionNasab>[
    CompanionNasab(
      'abubakr',
      'أبو بكر الصديق',
      'تيم بن مرة',
      ['عبد الله', 'عثمان (أبي قحافة)', 'عامر', 'عمرو', 'كعب', 'سعد', 'تيم', 'مرة'],
      7,
      NasabSource('فتح الباري، باب مناقب المهاجرين', 'https://www.islamweb.net/ar/library/content/52/6636/'),
      'وعدد آبائهما إلى مرة سواء.',
    ),
    CompanionNasab(
      'umar',
      'عمر بن الخطاب',
      'عدي بن كعب',
      ['عمر', 'الخطاب', 'نفيل', 'عبد العزى', 'رياح', 'عبد الله', 'قرط', 'رزاح', 'عدي', 'كعب'],
      8,
      NasabSource('فتح الباري، باب مناقب عمر', 'https://www.islamweb.net/ar/library/content/52/6683/'),
    ),
    CompanionNasab(
      'uthman',
      'عثمان بن عفان',
      'أمية بن عبد شمس',
      ['عثمان', 'عفان', 'أبي العاص', 'أمية', 'عبد شمس', 'عبد مناف'],
      4,
      NasabSource('فتح الباري، باب مناقب عثمان', 'https://www.islamweb.net/ar/library/content/52/6715/'),
    ),
    CompanionNasab(
      'ali',
      'علي بن أبي طالب',
      'بنو هاشم',
      ['علي', 'أبي طالب', 'عبد المطلب'],
      2,
      NasabSource('فتح الباري، باب مناقب علي بن أبي طالب', 'https://www.islamweb.net/ar/library/content/52/6727/'),
      'ابن عم رسول الله ﷺ، وأبو طالب شقيق عبد الله أبي النبي ﷺ.',
    ),
    CompanionNasab(
      'talha',
      'طلحة بن عبيد الله',
      'تيم بن مرة',
      ['طلحة', 'عبيد الله', 'عثمان', 'عمرو', 'كعب', 'سعد', 'تيم', 'مرة'],
      7,
      NasabSource('فتح الباري، باب ذكر طلحة بن عبيد الله', 'https://www.islamweb.net/ar/library/content/52/6764/'),
      'ويلتقي مع أبي بكر الصديق في تيم بن مرة.',
    ),
    CompanionNasab(
      'zubayr',
      'الزبير بن العوام',
      'أسد بن عبد العزى',
      ['الزبير', 'العوام', 'خويلد', 'أسد', 'عبد العزى', 'قصي'],
      5,
      NasabSource('فتح الباري، باب مناقب الزبير بن العوام', 'https://www.islamweb.net/ar/library/content/52/6755/'),
      'وأمه صفية بنت عبد المطلب عمة النبي ﷺ.',
    ),
    CompanionNasab(
      'awf',
      'عبد الرحمن بن عوف',
      'زهرة بن كلاب',
      ['عبد الرحمن', 'عوف', 'عبد عوف', 'عبد', 'الحارث', 'زهرة', 'كلاب'],
      6,
      NasabSource('سير أعلام النبلاء للذهبي، ترجمة عبد الرحمن بن عوف', 'https://www.islamweb.net/ar/library/content/60/5/'),
      'من بني زهرة أخوال النبي ﷺ.',
    ),
    CompanionNasab(
      'saad',
      'سعد بن أبي وقاص',
      'زهرة بن كلاب',
      ['سعد', 'مالك (أبي وقاص)', 'أهيب', 'عبد مناف', 'زهرة', 'كلاب'],
      6,
      NasabSource('فتح الباري، باب مناقب سعد بن أبي وقاص', 'https://www.islamweb.net/ar/library/content/52/6768/'),
      'ويقال: وهيب بدل أهيب. وهو من بني زهرة أخوال النبي ﷺ.',
    ),
    CompanionNasab(
      'said',
      'سعيد بن زيد',
      'عدي بن كعب',
      ['سعيد', 'زيد', 'عمرو', 'نفيل', 'عبد العزى', 'رياح', 'قرط', 'رزاح', 'عدي', 'كعب'],
      8,
      NasabSource('سير أعلام النبلاء للذهبي، ترجمة سعيد بن زيد', 'https://www.islamweb.net/ar/library/content/60/11/'),
      'ابن عم عمر بن الخطاب، يلتقي معه في نفيل بن عبد العزى.',
    ),
    CompanionNasab(
      'ubayda',
      'أبو عبيدة بن الجراح',
      'الحارث بن فهر',
      ['عامر', 'عبد الله', 'الجراح', 'هلال', 'أهيب', 'ضبة', 'الحارث', 'فهر'],
      11,
      NasabSource('فتح الباري، باب مناقب أبي عبيدة بن الجراح', 'https://www.islamweb.net/ar/library/content/52/6797/'),
      'ويقال: وهيب بدل أهيب.',
    ),
  ];

  static const sources = <NasabSource>[
    fath,
    zad,
    motherSource,
    NasabSource('سيرة ابن هشام، ذكر من أسلم بدعوة أبي بكر (بأنسابهم)', 'https://www.islamweb.net/ar/library/content/58/281/'),
    NasabSource('إسلام ويب، الفتوى ٦٤٣٢١: العشرة المبشرون بالجنة وبطونهم من قريش', 'https://www.islamweb.net/ar/fatwa/64321/'),
  ];
}
