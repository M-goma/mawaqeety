import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/data/fiqh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FiqhData d;
  setUpAll(() async => d = await FiqhData.load());

  test('data is complete and sourced', () {
    expect(d.items.length, inInclusiveRange(60, 80));
    expect(d.sources, isNotEmpty);
    expect(d.collected, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(d.topics, ['الطهارة', 'الصلاة', 'الصيام', 'الزكاة', 'الحج والعمرة']);
    final names = d.sources.map((s) => s.name).toSet();
    final hosts = {'www.islamweb.net', 'www.dar-alifta.org', 'www.azhar.eg'};
    for (final i in d.items) {
      expect(i.answers, isNotEmpty, reason: i.question);
      for (final a in i.answers) {
        expect(names, contains(a.source));
        expect(hosts, contains(Uri.parse(a.url).host), reason: a.url);
        expect(a.text.trim(), isNotEmpty);
        expect(a.ref.trim(), isNotEmpty);
      }
    }
    expect(d.items.map((i) => i.id).toSet().length, d.items.length);
  });

  test('topic filter and search', () {
    final salah = d.filter(topic: 'الصلاة');
    expect(salah, isNotEmpty);
    expect(salah.every((i) => i.topic == 'الصلاة'), isTrue);
    // diacritic/hamza-insensitive, all words must match
    final tay = d.filter(query: 'التَّيمم');
    expect(tay, isNotEmpty);
    expect(tay.every((i) => i.matches('تيمم')), isTrue);
    expect(d.filter(query: 'زكاة الفطر نقود'), isNotEmpty);
    expect(d.filter(topic: 'الصيام', query: 'التيمم'), isEmpty);
    expect(d.filter(query: 'كلمةغيرموجودة'), isEmpty);
    expect(d.filter(query: '  ').length, d.items.length);
  });
}
