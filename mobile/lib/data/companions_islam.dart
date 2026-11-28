/// كيف أسلم الصحابة: how and when each of the ten promised Paradise embraced Islam.
///
/// Hadith references are to the bundled Sahih al-Bukhari (assets/data/hadith_bukhari.json.gz) and each quoted
/// fragment is checked against it by test/nasab_test.dart. Everything else is quoted from pages that were opened
/// (see [IslamSource.url]); ages that the historians differ on are marked as such.
library;

class IslamSource {
  final String label, url;
  const IslamSource(this.label, this.url);
}

/// A quoted fragment of a hadith in the bundled Bukhari: [number] is the hadith number in the data file.
class IslamHadith {
  final String text;
  final int number;
  const IslamHadith(this.text, this.number);
}

class CompanionIslam {
  final String id, name;

  /// «على يد من» in a few words (e.g. «بدعوة أبي بكر»).
  final String by;

  /// 2–4 lines on how and when.
  final String story;

  /// Approximate age when he accepted Islam, as the historians state it (null = not given here).
  final String? age;

  /// True when the historians differ on the age.
  final bool ageDisputed;
  final IslamHadith? hadith;
  final List<IslamSource> sources;
  const CompanionIslam(this.id, this.name, this.by, this.story, this.sources, {this.age, this.ageDisputed = false, this.hadith});
}

class CompanionsIslam {
  static const _ibnHishamAbuBakr = IslamSource('سيرة ابن هشام: إسلام أبي بكر', 'https://www.islamweb.net/ar/library/content/58/280/');
  static const _ibnHishamFive = IslamSource('سيرة ابن هشام: من أسلم بدعوة أبي بكر', 'https://www.islamweb.net/ar/library/content/58/281/');
  static const _ibnHishamNext = IslamSource(
    'سيرة ابن هشام: إسلام أبي عبيدة وسعيد بن زيد وغيرهما',
    'https://www.islamweb.net/ar/library/content/58/282/',
  );
  static const _awail = IslamSource('إسلام ويب، الفتوى ٩٤٦٨٣: أوائل من دخلوا في الإسلام', 'https://www.islamweb.net/ar/fatwa/94683/');
  static const _ten = IslamSource('إسلام ويب: من هم العشرة المبشرون بالجنة؟', 'https://www.islamweb.net/ar/article/248278/');

  static const intro =
      'سبق هؤلاء العشرة إلى الإسلام في أيامه الأولى بمكة، وأكثرهم أسلم بدعوة أبي بكر الصديق رضي الله عنه. '
      'هنا خبر إسلام كل واحد منهم باختصار، مع حديث صحيح من البخاري حيث وُجد، ومصدر كل خبر.';

  static const footnote =
      'الأحاديث من صحيح البخاري برقمها في نسخة التطبيق، وأخبار السيرة منقولة من سيرة ابن هشام (عن ابن إسحاق) '
      'وسير أعلام النبلاء للذهبي وفتح الباري لابن حجر كما في المكتبة الإسلامية بموقع إسلام ويب. '
      'والأعمار تقريبية، وما اختلف فيه المؤرخون نُبّه عليه.';

  static const list = <CompanionIslam>[
    CompanionIslam(
      'abubakr',
      'أبو بكر الصديق',
      'أول من أسلم من الرجال',
      'أول من أسلم من الرجال الأحرار، ولما أسلم أظهر إسلامه ودعا إلى الله ورسوله، فأسلم بدعوته عثمان والزبير وعبد الرحمن بن عوف وسعد وطلحة. '
          'وقال عمار: رأيت رسول الله ﷺ وما معه إلا خمسة أعبد وامرأتان وأبو بكر (البخاري ٣٦٦٠).',
      [
        _awail,
        _ibnHishamAbuBakr,
        IslamSource(
          'إسلام ويب: أبو بكر الصديق.. نشأته وإسلامه (مولده بعد عام الفيل بسنتين وستة أشهر)',
          'https://www.islamweb.net/ar/article/233611/',
        ),
      ],
      age: 'نحو ٣٧–٣٨ سنة تقديرًا',
      hadith: IslamHadith('«إن الله بعثني إليكم فقلتم: كذبت، وقال أبو بكر: صدق، وواساني بنفسه وماله»', 3661),
    ),
    CompanionIslam(
      'umar',
      'عمر بن الخطاب',
      'بعد إسلام أخته وزوجها سعيد بن زيد',
      'أسلم في ذي الحجة من السنة السادسة من البعثة، فكان إسلامه عزًّا للمسلمين. '
          'وكانت أخته فاطمة وزوجها سعيد بن زيد قد سبقاه إلى الإسلام، قال سعيد: لقد رأيتني وإن عمر لموثقي على الإسلام قبل أن يسلم عمر (البخاري ٣٨٦٢).',
      [
        IslamSource('إسلام ويب: «اللهم أعز الإسلام بأحب هذين الرجلين إليك»', 'https://www.islamweb.net/ar/article/241585/'),
        IslamSource('إسلام ويب: سعيد بن زيد المبشر بالجنة', 'https://www.islamweb.net/ar/article/248266/'),
      ],
      age: '٢٦ سنة، وقال الذهبي: ٢٧ سنة',
      ageDisputed: true,
      hadith: IslamHadith('قال ابن مسعود: «ما زلنا أعزة منذ أسلم عمر»', 3863),
    ),
    CompanionIslam(
      'uthman',
      'عثمان بن عفان',
      'بدعوة أبي بكر',
      'من السابقين الأولين، أسلم بدعوة أبي بكر الصديق مع الزبير وعبد الرحمن بن عوف وسعد وطلحة، فجاء بهم أبو بكر إلى رسول الله ﷺ فأسلموا وصلّوا، '
          'فكانوا مع علي وزيد بن حارثة وأبي بكر «النفر الثمانية الذين سبقوا الناس بالإسلام».',
      [_ibnHishamFive],
      hadith: IslamHadith('قال عثمان: «وكنت ممن استجاب لله ولرسوله، وآمن بما بعث به محمد ﷺ، ثم هاجرت هجرتين»', 3927),
    ),
    CompanionIslam(
      'ali',
      'علي بن أبي طالب',
      'أول من أسلم من الصبيان',
      'كان في حجر رسول الله ﷺ قبل البعثة، ضمّه إليه تخفيفًا عن عمه أبي طالب في سنة شدة، فلما بُعث ﷺ اتبعه علي وآمن به وصدّقه، '
          'فهو أول من أسلم من الصبيان.',
      [
        IslamSource('سيرة ابن هشام: علي أول ذكر أسلم', 'https://www.islamweb.net/ar/library/content/58/277/'),
        IslamSource('فتح الباري، باب مناقب علي', 'https://www.islamweb.net/ar/library/content/52/6727/'),
        _awail,
      ],
      age: '١٠ سنين على الأرجح (وعن عروة: ٨)',
      ageDisputed: true,
    ),
    CompanionIslam(
      'talha',
      'طلحة بن عبيد الله',
      'بدعوة أبي بكر',
      'من السابقين الأولين، وأحد الخمسة الذين أسلموا بدعوة أبي بكر الصديق، وهو من قومه بني تيم، فجاء بهم أبو بكر إلى رسول الله ﷺ فأسلموا.',
      [_ibnHishamFive, _ten],
    ),
    CompanionIslam(
      'zubayr',
      'الزبير بن العوام',
      'بدعوة أبي بكر',
      'ابن عمة رسول الله ﷺ صفية بنت عبد المطلب، أسلم قديمًا بدعوة أبي بكر الصديق، وهو أول من سلّ سيفًا في سبيل الله.',
      [
        _ibnHishamFive,
        IslamSource('فتح الباري، باب مناقب الزبير (رواية عروة بإسناد صحيح)', 'https://www.islamweb.net/ar/library/content/52/6755/'),
        IslamSource('سير أعلام النبلاء، ترجمة الزبير', 'https://www.islamweb.net/ar/library/content/60/3/'),
      ],
      age: 'عن عروة: ٨ سنين، وقيل: ١٦ سنة',
      ageDisputed: true,
    ),
    CompanionIslam(
      'awf',
      'عبد الرحمن بن عوف',
      'بدعوة أبي بكر',
      'أحد الثمانية الذين بادروا إلى الإسلام، أسلم بدعوة أبي بكر الصديق، وكان اسمه في الجاهلية عبد عمرو، وقيل: عبد الكعبة، فسمّاه النبي ﷺ عبد الرحمن.',
      [_ibnHishamFive, IslamSource('سير أعلام النبلاء، ترجمة عبد الرحمن بن عوف', 'https://www.islamweb.net/ar/library/content/60/5/')],
    ),
    CompanionIslam(
      'saad',
      'سعد بن أبي وقاص',
      'بدعوة أبي بكر',
      'من بني زهرة أخوال النبي ﷺ، أسلم قديمًا بدعوة أبي بكر الصديق، وكان يقول إنه مكث أيامًا وهو ثلث الإسلام.',
      [
        _ibnHishamFive,
        IslamSource('سير أعلام النبلاء، ترجمة سعد (قول ابن منده في سنّه)', 'https://www.islamweb.net/ar/library/content/60/8/'),
      ],
      age: '١٧ سنة (ذكره ابن منده)',
      hadith: IslamHadith('قال سعد: «ما أسلم أحد إلا في اليوم الذي أسلمت فيه، ولقد مكثت سبعة أيام وإني لثلث الإسلام»', 3727),
    ),
    CompanionIslam(
      'said',
      'سعيد بن زيد',
      'أسلم قديمًا مع زوجته فاطمة بنت الخطاب',
      'ابن زيد بن عمرو بن نفيل الحنيف، أسلم مبكرًا قبل دخول النبي ﷺ دار الأرقم، وأسلمت معه زوجته فاطمة أخت عمر، وكانا سببًا في إسلام عمر.',
      [_ibnHishamNext, IslamSource('إسلام ويب: سعيد بن زيد المبشر بالجنة', 'https://www.islamweb.net/ar/article/248266/')],
      hadith: IslamHadith('قال سعيد: «لو رأيتني موثقي عمر على الإسلام أنا وأخته وما أسلم»', 3867),
    ),
    CompanionIslam(
      'ubayda',
      'أبو عبيدة بن الجراح',
      'من السابقين الأولين',
      'أسلم بعد النفر الثمانية في أول الإسلام، وفي رواية عند ابن سعد أنه أتى رسول الله ﷺ مع عثمان بن مظعون وعبد الرحمن بن عوف وغيرهما فعرض عليهم الإسلام فأسلموا في ساعة واحدة قبل دخول دار الأرقم، '
          'وذكر بعض أهل السير أنه أسلم بدعوة أبي بكر.',
      [_ibnHishamNext, IslamSource('سير أعلام النبلاء، ترجمة أبي عبيدة', 'https://www.islamweb.net/ar/library/content/60/1/'), _awail],
    ),
  ];
}
