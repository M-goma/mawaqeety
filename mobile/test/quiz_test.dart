import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqeety/core/arabic.dart';
import 'package:mawaqeety/data/asma.dart';
import 'package:mawaqeety/data/companions_islam.dart';
import 'package:mawaqeety/data/quiz.dart';

dynamic _json(String name) => jsonDecode(File('assets/data/$name').readAsStringSync());

String _join(Iterable<Object?> parts) => parts.whereType<String>().join('\n');

void main() {
  final bank = QuizBank.parse(File('assets/data/quiz.json').readAsStringSync());

  final prophets = {for (final p in _json('prophets.json') as List) p['id']: p};
  final ghazawat = {for (final g in (_json('ghazawat.json') as Map)['items'] as List) g['id']: g};
  final companions = {for (final c in (_json('companions.json') as Map)['companions'] as List) c['id']: c};
  final arbaeen = {for (final h in (_json('arbaeen.json') as Map)['hadiths'] as List) h['n']: h};
  final fiqh = {for (final i in (_json('fiqh.json') as Map)['items'] as List) i['id']: i};
  final quran = {for (final s in _json('quran.json') as List) s['n']: s};
  final islam = {for (final c in CompanionsIslam.list) c.id: c};
  final asma = {for (final a in asmaAlHusna) a.$1: a.$2};

  /// The text of the item a question points to, or null if the reference does not resolve.
  String? itemText(QuizRef r) {
    switch (r.src) {
      case 'prophets':
        final p = prophets[r.id];
        if (p == null) return null;
        return _join([
          p['nameAr'], p['title'], p['summary'], ...p['lessons'],
          for (final s in p['sections']) ...[s['heading'], s['body']],
        ]);
      case 'ghazawat':
        final g = ghazawat[r.id];
        if (g == null) return null;
        return _join([
          for (final k in ['name', 'date', 'place', 'muslims', 'enemy', 'result', 'summary']) g[k],
          ...g['lessons'],
          for (final s in g['sections']) ...[s['h'], s['p']],
        ]);
      case 'companions':
        final c = companions[r.id];
        if (c == null) return null;
        return _join([c['name'], c['title'], c['bio'], for (final s in c['situations']) ...[s['title'], s['text']]]);
      case 'companions_islam':
        final c = islam[r.id];
        if (c == null) return null;
        return _join([c.name, c.by, c.story, c.age, c.hadith?.text]);
      case 'arbaeen':
        final h = arbaeen[r.n];
        if (h == null) return null;
        return _join([h['title'], h['narrator'], h['text'], h['takhrij'], ...?h['benefits']]);
      case 'fiqh':
        final i = fiqh[r.id];
        if (i == null) return null;
        return _join([i['q'], for (final a in i['answers']) a['text']]);
      case 'asma':
        final m = asma[r.name];
        return m == null ? null : '${r.name}\n$m';
      case 'quran':
        final s = quran[r.n];
        return s == null ? null : s['name'] as String;
    }
    return null;
  }

  test('7 categories with 15–30 questions each, unique ids', () {
    expect(bank.categories.map((c) => c.id), ['prophets', 'ghazawat', 'companions', 'arbaeen', 'fiqh', 'asma', 'quran']);
    for (final c in bank.categories) {
      expect(bank.inCategory(c.id).length, inInclusiveRange(15, 30), reason: c.id);
    }
    expect(bank.questions.map((q) => q.id).toSet().length, bank.questions.length);
    expect(bank.questions.every((q) => bank.category(q.category) != null), isTrue);
  });

  test('every question has 4 distinct options and exactly one correct answer', () {
    for (final q in bank.questions) {
      expect(q.options.length, 4, reason: q.id);
      expect(q.options.map(Arabic.normalize).toSet().length, 4, reason: q.id);
      expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
      expect(q.options.where((o) => o == q.correct).length, 1, reason: q.id);
      expect(q.question, isNotEmpty);
      expect(q.explanation, isNotEmpty);
      expect(q.source, isNotEmpty);
    }
  });

  test('every source reference resolves to an item, and its text supports the answer', () {
    for (final q in bank.questions) {
      final text = itemText(q.ref);
      expect(text, isNotNull, reason: '${q.id}: ${q.ref.src} ${q.ref.id ?? q.ref.n ?? q.ref.name}');
      if (q.ref.src == 'quran') {
        expect(q.kind, isNotNull, reason: q.id);
        continue;
      }
      expect(q.proof, isNotNull, reason: q.id);
      expect(Arabic.normalize(text!).contains(Arabic.normalize(q.proof!)), isTrue, reason: '${q.id}: «${q.proof}»');
    }
  });

  test('fiqh questions only come from items without khilaf', () {
    final f = bank.questions.where((q) => q.ref.src == 'fiqh').toList();
    expect(f, isNotEmpty);
    for (final q in f) {
      expect(fiqh[q.ref.id]['khilaf'], isFalse, reason: q.id);
    }
  });

  test('generated answers match the data they come from', () {
    for (final q in bank.questions) {
      final r = q.ref;
      switch (r.src) {
        case 'ghazawat' when q.question.startsWith('في أي سنة'):
          expect(q.correct, 'سنة ${Arabic.digits(ghazawat[r.id]['year'])} هـ', reason: q.id);
        case 'arbaeen' when q.question.startsWith('من راوي'):
          expect(q.correct, arbaeen[r.n]['narrator'], reason: q.id);
        case 'asma':
          expect(q.correct, r.name, reason: q.id);
          expect(q.question, contains(asma[r.name]!));
        case 'prophets' when q.question.contains('من ألقابه'):
          expect(q.correct, prophets[r.id]['nameAr'], reason: q.id);
        case 'quran':
          final s = quran[r.n];
          switch (q.kind!['t']) {
            case 'type':
              expect(q.correct, s['name'], reason: q.id);
              final others = [for (final n in q.kind!['others'] as List) quran[n]];
              expect(others.map((o) => o['name']).toSet(), q.options.where((o) => o != q.correct).toSet(), reason: q.id);
              for (final o in others) {
                expect(o['type'], isNot(s['type']), reason: '${q.id}: ${o['name']}');
              }
              expect(q.question, contains(s['type'] == 'm' ? 'مكية' : 'مدنية'));
            case 'count':
              expect(q.correct, Arabic.digits((s['v'] as List).length), reason: q.id);
              expect(q.question, contains(s['name']));
            case 'order':
              expect(q.correct, Arabic.digits(r.n!), reason: q.id);
              expect(q.question, contains(s['name']));
            default:
              fail('${q.id}: unknown kind');
          }
      }
    }
  });

  test('a round has 10 different questions; «منوّعة» mixes the categories', () {
    for (final id in [...bank.categories.map((c) => c.id), QuizBank.mixed]) {
      final r = bank.round(id, Random(7));
      expect(r.length, QuizBank.roundSize);
      expect(r.map((i) => i.q.id).toSet().length, QuizBank.roundSize);
      for (final i in r) {
        expect(i.options[i.answer], i.q.correct);
        if (id != QuizBank.mixed) expect(i.q.category, id);
      }
      if (id == QuizBank.mixed) expect(r.map((i) => i.q.category).toSet().length, greaterThanOrEqualTo(5));
    }
  });

  test('stats: best score, streak of days, totals survive a round trip', () {
    final s = QuizStats();
    expect(s.record('ghazawat', 7, 10, DateTime(2026, 11, 1)), isTrue);
    expect(s.record('ghazawat', 5, 10, DateTime(2026, 11, 1)), isFalse);
    s.record('fiqh', 9, 10, DateTime(2026, 11, 2));
    expect(s.best, {'ghazawat': 7, 'fiqh': 9});
    expect(s.streak, 2);
    expect(s.streakOn(DateTime(2026, 11, 3)), 2);
    expect(s.streakOn(DateTime(2026, 11, 4)), 0);
    s.record('fiqh', 10, 10, DateTime(2026, 11, 5));
    expect(s.streak, 1);
    expect(s.bestStreak, 2);
    expect(s.accuracy, 78);
    final back = QuizStats.decode(jsonEncode(s.toJson()));
    expect(back.toJson(), s.toJson());
    expect(QuizStats.decode('garbage').rounds, 0);
    expect([quizStars(10, 10), quizStars(9, 10), quizStars(7, 10), quizStars(5, 10), quizStars(4, 10)], [3, 3, 2, 1, 0]);
  });
}
