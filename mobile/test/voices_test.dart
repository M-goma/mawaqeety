import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/settings.dart';

void main() {
  test('Alafasy is removed and saved choices move to Minshawi / Cairo Fajr', () {
    final adhan = File('assets/data/adhan_voices.json').readAsStringSync();
    final reciters = File('assets/data/reciters.json').readAsStringSync();
    expect(RegExp('afasy|mishary', caseSensitive: false).hasMatch(adhan), isFalse);
    expect(RegExp('afasy', caseSensitive: false).hasMatch(reciters), isFalse);
    final s = Settings.fromJsonString(jsonEncode({'adhanId': 'alafasy', 'fajrAdhanId': 'alafasy-fajr', 'reciterId': 'Alafasy_128kbps'}));
    expect(s.adhanId, 'minshawi');
    expect(s.fajrAdhanId, 'cairo-fajr');
    expect(s.reciterId, 'Minshawy_Murattal_128kbps');
    final ids = [for (final v in jsonDecode(adhan) as List) v['id']];
    expect(ids, containsAll(['minshawi', 'cairo-fajr']));
    expect(reciters.contains('Minshawy_Murattal_128kbps'), isTrue);
  });
}
