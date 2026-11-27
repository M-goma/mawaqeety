/// Places of the prophets' stories. Only places named in the Qur'an or the Sunnah, or identified by most
/// commentators; the level of certainty is shown with each one.
enum AtlasCertainty { text, most, said }

extension AtlasCertaintyX on AtlasCertainty {
  String get label => const ['ثابت بالنص', 'قول أكثر المفسرين', 'قول بعض المؤرخين'][index];
}

class AtlasPlace {
  final String name, note, source;
  final double lat, lng;
  final List<String> prophets; // ids from prophets.json
  final AtlasCertainty certainty;
  const AtlasPlace(this.name, this.lat, this.lng, this.prophets, this.note, this.source, this.certainty);
}

const atlasPlaces = <AtlasPlace>[
  AtlasPlace('مكة المكرمة', 21.4225, 39.8262, ['ibrahim', 'ismail', 'muhammad'],
      'رفع إبراهيم وإسماعيل عليهما السلام قواعد البيت، ووُلد فيها النبي ﷺ وبُعث.',
      'البقرة ١٢٧، إبراهيم ٣٧', AtlasCertainty.text),
  AtlasPlace('المدينة المنورة', 24.4672, 39.6111, ['muhammad'],
      'هاجر إليها النبي ﷺ، وفيها مسجده وقبره.', 'التوبة ١٢٠، الأحزاب ١٣', AtlasCertainty.text),
  AtlasPlace('بيت المقدس', 31.7781, 35.2360, ['dawud', 'sulaiman', 'zakariya', 'yahya', 'isa', 'muhammad'],
      'إليه أُسري بالنبي ﷺ من المسجد الحرام، وهو من الأرض المباركة التي بُعث فيها أنبياء بني إسرائيل.',
      'الإسراء ١، الأنبياء ٧١', AtlasCertainty.text),
  AtlasPlace('أرض الشام المباركة (فلسطين)', 31.53, 35.10, ['ibrahim', 'lut', 'ishaq', 'yaqub'],
      'نجّى الله إبراهيم ولوطًا إلى الأرض التي بارك فيها، وفيها نشأ إسحاق ويعقوب عليهم السلام.',
      'الأنبياء ٧١–٧٢', AtlasCertainty.most),
  AtlasPlace('مصر', 30.04, 31.24, ['yusuf', 'yaqub', 'musa', 'harun'],
      'مكّن الله فيها ليوسف، ودخلها أبواه وإخوته، وفيها كانت دعوة موسى وهارون لفرعون.',
      'يوسف ٢١ و٩٩، يونس ٨٧', AtlasCertainty.text),
  AtlasPlace('طور سيناء', 28.539, 33.975, ['musa'],
      'كلّم الله موسى عليه السلام عند جانب الطور. والموضع المحدد للجبل على المشهور عند المؤرخين.',
      'القصص ٢٩–٣٠، المؤمنون ٢٠', AtlasCertainty.most),
  AtlasPlace('مدين', 28.48, 34.90, ['shuayb', 'musa'],
      'أرسل الله شعيبًا إلى أهل مدين، وإليها خرج موسى فارًّا من مصر. وهي شمال غرب الجزيرة قرب خليج العقبة على قول أكثر المفسرين.',
      'الأعراف ٨٥، القصص ٢٢', AtlasCertainty.most),
  AtlasPlace('الحِجر (ديار ثمود)', 26.79, 37.95, ['salih'],
      'ديار ثمود قوم صالح الذين نحتوا الجبال بيوتًا، في شمال غرب الجزيرة العربية.',
      'الحجر ٨٠–٨٢، الأعراف ٧٤', AtlasCertainty.most),
  AtlasPlace('الأحقاف (ديار عاد)', 16.6, 48.5, ['hud'],
      'أنذر هود عليه السلام قومه عادًا بالأحقاف، وهي في جنوب الجزيرة العربية على قول أكثر المفسرين.',
      'الأحقاف ٢١', AtlasCertainty.most),
  AtlasPlace('قرى قوم لوط', 31.45, 35.45, ['lut'],
      'القرى التي جعل الله عاليها سافلها، وهي قرب البحر الميت على قول كثير من المفسرين والمؤرخين.',
      'هود ٨٢، الحجر ٧٦', AtlasCertainty.most),
  AtlasPlace('جبل الجودي', 37.38, 42.35, ['nuh'],
      'عليه استوت سفينة نوح عليه السلام. والجبل المعروف بهذا الاسم قرب الموصل وجنوب تركيا، وفي تعيينه خلاف.',
      'هود ٤٤', AtlasCertainty.said),
  AtlasPlace('العراق (أرض بابل)', 31.0, 46.1, ['ibrahim'],
      'كانت دعوة إبراهيم عليه السلام لقومه وأبيه في العراق على قول المؤرخين.',
      'الأنبياء ٥١–٧٠', AtlasCertainty.said),
  AtlasPlace('نينوى', 36.36, 43.15, ['yunus'],
      'أُرسل يونس عليه السلام إلى قوم آمنوا كلهم، وهم أهل نينوى قرب الموصل على المشهور عند المؤرخين.',
      'يونس ٩٨، الصافات ١٤٧', AtlasCertainty.said),
];
