/// Prayer-time conventions (identical to the desktop app's CalculationMethod table).
enum MethodId {
  egyptian, muslimWorldLeague, ummAlQura, karachi, isna, dubai, kuwait, qatar, gulf,
  singapore, turkey, france, russia, morocco, algeria, tunisia, jordan, tehran, jafari, custom,
}

enum AsrMadhab { shafii, hanafi }

enum HighLatitudeRule { none, angleBased, oneSeventh, middleOfNight }

class CalculationMethod {
  final MethodId id;
  final String nameAr;
  final String nameEn;
  final double fajrAngle;
  final double? ishaAngle;
  final int? ishaMinutes;
  final double? maghribAngle;
  final int maghribMinutes;
  final int? ishaMinutesInRamadan;

  const CalculationMethod(this.id, this.nameAr, this.nameEn, this.fajrAngle, this.ishaAngle,
      {this.ishaMinutes, this.maghribAngle, this.maghribMinutes = 0, this.ishaMinutesInRamadan});

  CalculationMethod withAngles(double fajr, double isha) => CalculationMethod(id, nameAr, nameEn, fajr, isha);

  static const all = <CalculationMethod>[
    CalculationMethod(MethodId.egyptian, 'الهيئة المصرية العامة للمساحة', 'Egyptian General Authority of Survey', 19.5, 17.5),
    CalculationMethod(MethodId.muslimWorldLeague, 'رابطة العالم الإسلامي', 'Muslim World League', 18, 17),
    CalculationMethod(MethodId.ummAlQura, 'جامعة أم القرى - مكة المكرمة', 'Umm Al-Qura, Makkah', 18.5, null, ishaMinutes: 90, ishaMinutesInRamadan: 120),
    CalculationMethod(MethodId.karachi, 'جامعة العلوم الإسلامية - كراتشي', 'Karachi', 18, 18),
    CalculationMethod(MethodId.isna, 'الجمعية الإسلامية لأمريكا الشمالية', 'ISNA', 15, 15),
    CalculationMethod(MethodId.dubai, 'دبي - الإمارات', 'Dubai', 18.2, 18.2),
    CalculationMethod(MethodId.kuwait, 'الكويت', 'Kuwait', 18, 17.5),
    CalculationMethod(MethodId.qatar, 'قطر', 'Qatar', 18, null, ishaMinutes: 90),
    CalculationMethod(MethodId.gulf, 'منطقة الخليج', 'Gulf Region', 19.5, null, ishaMinutes: 90),
    CalculationMethod(MethodId.singapore, 'سنغافورة / ماليزيا / إندونيسيا', 'Singapore', 20, 18),
    CalculationMethod(MethodId.turkey, 'رئاسة الشؤون الدينية - تركيا', 'Diyanet, Turkey', 18, 17),
    CalculationMethod(MethodId.france, 'اتحاد المنظمات الإسلامية - فرنسا', 'UOIF, France', 12, 12),
    CalculationMethod(MethodId.russia, 'الإدارة الدينية لمسلمي روسيا', 'Russia', 16, 15),
    CalculationMethod(MethodId.morocco, 'وزارة الأوقاف - المغرب', 'Morocco', 19, 17),
    CalculationMethod(MethodId.algeria, 'وزارة الشؤون الدينية - الجزائر', 'Algeria', 18, 17),
    CalculationMethod(MethodId.tunisia, 'وزارة الشؤون الدينية - تونس', 'Tunisia', 18, 18),
    CalculationMethod(MethodId.jordan, 'وزارة الأوقاف - الأردن', 'Jordan', 18, 18),
    CalculationMethod(MethodId.tehran, 'معهد الجيوفيزياء - جامعة طهران', 'Tehran', 17.7, 14, maghribAngle: 4.5),
    CalculationMethod(MethodId.jafari, 'الشيعة الإثنا عشرية - قم', 'Jafari, Qum', 16, 14, maghribAngle: 4),
    CalculationMethod(MethodId.custom, 'زوايا مخصصة', 'Custom angles', 18, 17),
  ];

  static CalculationMethod get(MethodId id) => all.firstWhere((m) => m.id == id);

  static MethodId defaultForCountry(String? cc) {
    switch ((cc ?? '').toUpperCase()) {
      case 'EG': case 'SD': case 'SS': case 'LY': case 'SY': case 'LB': case 'IQ': case 'PS': case 'YE':
        return MethodId.egyptian;
      case 'SA': return MethodId.ummAlQura;
      case 'AE': return MethodId.dubai;
      case 'KW': return MethodId.kuwait;
      case 'QA': return MethodId.qatar;
      case 'BH': case 'OM': return MethodId.gulf;
      case 'JO': return MethodId.jordan;
      case 'MA': return MethodId.morocco;
      case 'DZ': return MethodId.algeria;
      case 'TN': return MethodId.tunisia;
      case 'TR': return MethodId.turkey;
      case 'FR': case 'BE': return MethodId.france;
      case 'RU': return MethodId.russia;
      case 'IR': return MethodId.tehran;
      case 'PK': case 'IN': case 'BD': case 'AF': return MethodId.karachi;
      case 'MY': case 'SG': case 'ID': case 'BN': return MethodId.singapore;
      case 'US': case 'CA': return MethodId.isna;
      default: return MethodId.muslimWorldLeague;
    }
  }

  static AsrMadhab defaultMadhabForCountry(String? cc) =>
      const {'PK', 'IN', 'BD', 'AF'}.contains((cc ?? '').toUpperCase()) ? AsrMadhab.hanafi : AsrMadhab.shafii;
}
