import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/ui/share_card.dart';
import 'package:mawaqeety/ui/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(rootBundle.load(f));
  }
  await l.load();
}

void main() {
  testWidgets('share card renders', (t) async {
    await t.runAsync(() async {
      await _font('AmiriQuran', ['assets/fonts/AmiriQuran-Regular.ttf']);
      await _font('Cairo', ['assets/fonts/Cairo-Regular.ttf', 'assets/fonts/Cairo-Bold.ttf']);
      AppColors.current = paletteById('mocha');
      final out = Platform.environment['SHARE_OUT'];
      final a = await renderCard(text: 'عن أبي هريرة قال: «أوصاني خليلي ﷺ بثلاث: صيام ثلاثة أيام من كل شهر، وركعتي الضحى، وأن أوتر قبل أن أنام»',
          ref: 'صحيح البخاري ١٩٨١ • صحيح مسلم ٧٢١', title: 'من الأحاديث الصحيحة');
      expect(a.length, greaterThan(10000));
      if (out != null) File('$out/share1.png').writeAsBytesSync(a);
      AppColors.current = paletteById('emerald');
      final b = await renderCard(text: 'الرحمن', ref: 'ذو الرحمة الواسعة التي وسعت كل شيء', title: 'من أسماء الله الحسنى');
      if (out != null) File('$out/share2.png').writeAsBytesSync(b);
    });
  });
}
