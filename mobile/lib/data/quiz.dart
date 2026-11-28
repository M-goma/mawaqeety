import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// مسابقات قصيرة (assets/data/quiz.json, built by tools/build_quiz.py) made only from the app's own content.
///
/// Each question points back to the item it comes from ([QuizRef]) and keeps the phrase of that item that
/// supports its answer ([QuizQuestion.proof]); test/quiz_test.dart checks both against the bundled data.
class QuizRef {
  /// prophets | ghazawat | companions | companions_islam | arbaeen | fiqh | asma | quran
  final String src;

  /// Item id (prophets, ghazawat, companions, companions_islam, fiqh as a number).
  final Object? id;

  /// Hadith number (arbaeen) or surah number (quran).
  final int? n;

  /// The name, for asma.
  final String? name;
  const QuizRef(this.src, {this.id, this.n, this.name});

  factory QuizRef.fromJson(Map<String, dynamic> j) => QuizRef(j['src'] as String, id: j['id'], n: j['n'] as int?, name: j['name'] as String?);
}

class QuizQuestion {
  final String id, category, question, explanation;

  /// Where the answer is in the app («غزوات النبي ﷺ • غزوة بدر الكبرى»).
  final String source;
  final List<String> options;
  final int answer;
  final QuizRef ref;

  /// The phrase of the source item that supports the answer (null for questions checked structurally).
  final String? proof;

  /// For generated Qur'an questions: {"t": "type" | "count" | "order", "others": [...]}.
  final Map<String, dynamic>? kind;
  const QuizQuestion(this.id, this.category, this.question, this.options, this.answer, this.explanation, this.source, this.ref,
      {this.proof, this.kind});

  String get correct => options[answer];

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        j['id'] as String,
        j['cat'] as String,
        j['q'] as String,
        [for (final o in j['o'] as List) o as String],
        j['a'] as int,
        j['ex'] as String,
        j['src'] as String,
        QuizRef.fromJson(j['ref'] as Map<String, dynamic>),
        proof: j['p'] as String?,
        kind: j['k'] as Map<String, dynamic>?,
      );
}

class QuizCategory {
  final String id, name, icon, desc;
  const QuizCategory(this.id, this.name, this.icon, this.desc);
}

/// One question as shown in a round: the options in a shuffled order.
class QuizItem {
  final QuizQuestion q;
  final List<String> options;
  final int answer;
  const QuizItem(this.q, this.options, this.answer);
}

class QuizBank {
  /// Questions per round.
  static const roundSize = 10;

  /// Id used for the «منوّعة» round (questions from every category).
  static const mixed = 'mixed';

  final String note;
  final List<QuizCategory> categories;
  final List<QuizQuestion> questions;
  const QuizBank(this.note, this.categories, this.questions);

  static QuizBank parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return QuizBank(
      j['note'] as String,
      [for (final c in j['categories'] as List) QuizCategory(c['id'], c['name'], c['icon'], c['desc'])],
      [for (final q in j['questions'] as List) QuizQuestion.fromJson(q as Map<String, dynamic>)],
    );
  }

  static QuizBank? _cache;
  static Future<QuizBank> load() async => _cache ??= parse(await rootBundle.loadString('assets/data/quiz.json'));

  List<QuizQuestion> inCategory(String id) => id == mixed ? questions : [for (final q in questions) if (q.category == id) q];

  QuizCategory? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(String id) => id == mixed ? 'منوّعة' : category(id)?.name ?? id;

  /// [roundSize] random questions of the category (all categories for [mixed]), options shuffled.
  /// A mixed round takes the questions from as many categories as it can.
  List<QuizItem> round(String id, Random rnd) {
    final List<QuizQuestion> picked;
    if (id == mixed) {
      final byCat = {for (final c in categories) c.id: inCategory(c.id)..shuffle(rnd)};
      final order = byCat.keys.toList()..shuffle(rnd);
      picked = [];
      for (var i = 0; picked.length < roundSize && i < questions.length; i++) {
        final list = byCat[order[i % order.length]]!;
        final k = i ~/ order.length;
        if (k < list.length) picked.add(list[k]);
      }
      picked.shuffle(rnd);
    } else {
      picked = (inCategory(id)..shuffle(rnd)).take(roundSize).toList();
    }
    return [
      for (final q in picked)
        () {
          final opts = [...q.options]..shuffle(rnd);
          return QuizItem(q, opts, opts.indexOf(q.correct));
        }(),
    ];
  }
}

/// 3 stars from 9/10, 2 from 7, 1 from 5.
int quizStars(int score, int total) {
  if (total == 0) return 0;
  final r = score / total;
  return r >= 0.9 ? 3 : r >= 0.7 ? 2 : r >= 0.5 ? 1 : 0;
}

/// Totals kept on the device (SharedPreferences key `quiz.stats`, like `arbaeen.memorized`).
class QuizStats {
  static const key = 'quiz.stats';

  /// Best score (out of [QuizBank.roundSize]) per category id, «منوّعة» included.
  final Map<String, int> best;
  int rounds, answered, correct;

  /// Days in a row with at least one round, the best such run, and the last day played (yyyy-mm-dd).
  int streak, bestStreak;
  String lastDay;

  /// Countdown per question (off by default).
  bool timer;

  QuizStats({Map<String, int>? best, this.rounds = 0, this.answered = 0, this.correct = 0, this.streak = 0, this.bestStreak = 0,
      this.lastDay = '', this.timer = false})
      : best = best ?? {};

  int get accuracy => answered == 0 ? 0 : (correct * 100 / answered).round();

  /// The streak as it stands on [today]: it lapses when yesterday was missed.
  int streakOn(DateTime today) {
    if (lastDay.isEmpty) return 0;
    final last = DateTime.tryParse(lastDay);
    if (last == null) return 0;
    final d = DateTime(today.year, today.month, today.day).difference(DateTime(last.year, last.month, last.day)).inDays;
    return d <= 1 ? streak : 0;
  }

  /// Adds a finished round. Returns true if it beats the category's best score.
  bool record(String category, int score, int total, DateTime today) {
    final record = score > (best[category] ?? -1);
    if (record) best[category] = score;
    rounds++;
    answered += total;
    correct += score;
    final day = _day(today);
    if (day != lastDay) {
      streak = streakOn(today) + 1;
      lastDay = day;
    }
    if (streak > bestStreak) bestStreak = streak;
    return record && score > 0;
  }

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'best': best, 'rounds': rounds, 'answered': answered, 'correct': correct,
        'streak': streak, 'bestStreak': bestStreak, 'lastDay': lastDay, 'timer': timer,
      };

  factory QuizStats.fromJson(Map<String, dynamic> j) => QuizStats(
        best: {for (final e in ((j['best'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
        rounds: (j['rounds'] as num?)?.toInt() ?? 0,
        answered: (j['answered'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
        lastDay: j['lastDay'] as String? ?? '',
        timer: j['timer'] == true,
      );

  static QuizStats decode(String? s) {
    if (s == null || s.isEmpty) return QuizStats();
    try {
      return QuizStats.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return QuizStats();
    }
  }

  static Future<QuizStats> load() async => decode((await SharedPreferences.getInstance()).getString(key));

  Future<void> save() async => (await SharedPreferences.getInstance()).setString(key, jsonEncode(toJson()));
}
