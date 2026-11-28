import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/arbaeen.dart';
import '../data/fiqh.dart';
import '../data/ghazawat.dart';
import '../data/quiz.dart';
import '../main.dart';
import 'arbaeen_page.dart';
import 'asma_page.dart';
import 'companions_islam_page.dart';
import 'companions_page.dart';
import 'fiqh_page.dart';
import 'ghazawat_page.dart';
import 'mushaf_page.dart';
import 'prophets_page.dart';
import 'share_card.dart';
import 'theme.dart';

const _right = Color(0xFF2E9E6A);
const _wrong = Color(0xFFD9534F);

/// Seconds per question when the timer is on.
const _seconds = 25;

/// مسابقات: pick a category (or «منوّعة»), answer 10 questions, see the source of each answer.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final Future<(QuizBank, QuizStats)> _load = _init();

  static Future<(QuizBank, QuizStats)> _init() async => (await QuizBank.load(), await QuizStats.load());
  QuizStats? _stats;

  Future<void> _start(QuizBank bank, String category) async {
    final stats = _stats!;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizRoundPage(bank: bank, category: category, stats: stats)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسابقات')),
      body: FutureBuilder(
        future: _load,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('تعذّر تحميل المسابقات: ${snap.error}'));
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final bank = d.$1;
          final st = _stats ??= d.$2;
          final hint = Theme.of(context).hintColor;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            _hero(st),
            Card3D(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SwitchListTile(
                secondary: const Icon(Icons.timer_outlined),
                title: const Text('المؤقّت', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${Arabic.digits(_seconds)} ثانية لكل سؤال'),
                value: st.timer,
                onChanged: (v) {
                  setState(() => st.timer = v);
                  st.save();
                },
              ),
            ),
            _CategoryTile(
              icon: '🎲',
              name: 'منوّعة',
              desc: 'أسئلة من كل الأقسام',
              count: bank.questions.length,
              best: st.best[QuizBank.mixed],
              gold: true,
              onTap: () => _start(bank, QuizBank.mixed),
            ),
            for (final c in bank.categories)
              _CategoryTile(
                icon: c.icon,
                name: c.name,
                desc: c.desc,
                count: bank.inCategory(c.id).length,
                best: st.best[c.id],
                onTap: () => _start(bank, c.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Text(bank.note, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: hint, height: 1.7)),
            ),
          ]);
        },
      ),
    );
  }

  Widget _hero(QuizStats st) {
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.heroText, fontSize: 12)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: hero3D(radius: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Tile3D(size: 48, gold: true, child: Icon(Icons.emoji_events_rounded, color: AppColors.current.bg, size: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مسابقات سبيل', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))])),
              Text('${Arabic.digits(QuizBank.roundSize)} أسئلة في كل جولة، ولكل جواب مصدره في التطبيق',
                  style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          stat(Arabic.digits(st.rounds), 'جولة'),
          stat('${Arabic.digits(st.accuracy)}٪', 'نسبة الصواب'),
          stat('🔥 ${Arabic.digits(st.streakOn(app.today))}', 'أيام متتالية'),
          stat(Arabic.digits(st.bestStreak), 'أطول سلسلة'),
        ]),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String icon, name, desc;
  final int count;
  final int? best;
  final bool gold;
  final VoidCallback onTap;
  const _CategoryTile({required this.icon, required this.name, required this.desc, required this.count, required this.best,
      required this.onTap, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Tile3D(size: 46, gold: gold, child: Text(icon, style: const TextStyle(fontSize: 22))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Text('$desc • ${Arabic.digits(count)} سؤالًا', style: TextStyle(fontSize: 12.5, color: hint)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          _Stars(best == null ? 0 : quizStars(best!, QuizBank.roundSize), size: 15),
          const SizedBox(height: 2),
          Text(best == null ? 'لم تُلعب' : 'الأفضل ${Arabic.digits(best!)}/${Arabic.digits(QuizBank.roundSize)}',
              style: TextStyle(fontSize: 11.5, color: hint)),
        ]),
        onTap: onTap,
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int n;
  final double size;
  const _Stars(this.n, {this.size = 20});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < n ? AppColors.gold : Theme.of(context).hintColor),
      ]);
}

/// One round: [QuizBank.roundSize] questions, feedback after each, then the score.
class QuizRoundPage extends StatefulWidget {
  final QuizBank bank;
  final String category;
  final QuizStats stats;

  /// Fixed seed (tests and screenshots); random otherwise.
  final int? seed;
  const QuizRoundPage({super.key, required this.bank, required this.category, required this.stats, this.seed});
  @override
  State<QuizRoundPage> createState() => _QuizRoundPageState();
}

class _QuizRoundPageState extends State<QuizRoundPage> {
  late List<QuizItem> _items;
  int _i = 0, _score = 0, _run = 0, _bestRun = 0;

  /// The chosen option of the current question; -1 when time ran out; null before answering.
  int? _chosen;
  final _answers = <int?>[];
  bool _done = false, _record = false;
  Timer? _timer;
  int _left = _seconds;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newRound() {
    _items = widget.bank.round(widget.category, Random(widget.seed));
    _i = _score = _run = _bestRun = 0;
    _chosen = null;
    _answers.clear();
    _done = _record = false;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.stats.timer) return;
    _left = _seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _chosen != null) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _answer(-1);
      }
    });
  }

  void _answer(int i) {
    if (_chosen != null) return;
    _timer?.cancel();
    final ok = i == _items[_i].answer;
    setState(() {
      _chosen = i;
      _answers.add(i);
      if (ok) {
        _score++;
        _bestRun = max(_bestRun, ++_run);
      } else {
        _run = 0;
      }
    });
  }

  void _next() {
    if (_i + 1 < _items.length) {
      setState(() {
        _i++;
        _chosen = null;
      });
      _startTimer();
      return;
    }
    final st = widget.stats;
    _record = st.record(widget.category, _score, _items.length, app.today);
    st.save();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.bank.categoryName(widget.category);
    return Scaffold(
      appBar: AppBar(title: Text(_done ? 'النتيجة' : 'مسابقة: $name')),
      body: _done ? _result(name) : _question(),
    );
  }

  Widget _question() {
    final it = _items[_i];
    final hint = Theme.of(context).hintColor;
    final answered = _chosen != null;
    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: hero3D(radius: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('السؤال ${Arabic.digits(_i + 1)} من ${Arabic.digits(_items.length)}',
                style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            if (_run >= 2) Text('🔥 ${Arabic.digits(_run)} متتالية', style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
            const SizedBox(width: 10),
            Text('✓ ${Arabic.digits(_score)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_i + (answered ? 1 : 0)) / _items.length,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: AppColors.goldLight,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.category == QuizBank.mixed)
            Text(widget.bank.categoryName(it.q.category), style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
          Text(it.q.question, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.7)),
          if (widget.stats.timer && !answered) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.timer_outlined, size: 16, color: _left <= 5 ? _wrong : AppColors.heroText),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _left / _seconds,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    color: _left <= 5 ? _wrong : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(Arabic.digits(_left), style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
            ]),
          ],
        ]),
      ),
      for (var k = 0; k < it.options.length; k++) _option(it, k),
      if (answered) _feedback(it, hint),
    ]);
  }

  Widget _option(QuizItem it, int k) {
    final answered = _chosen != null;
    final isRight = k == it.answer;
    final isChosen = k == _chosen;
    final Color? edge = !answered ? null : isRight ? _right : isChosen ? _wrong : null;
    return Card3D(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: edge == null ? null : RoundedRectangleBorder(side: BorderSide(color: edge, width: 2)),
      color: edge?.withValues(alpha: 0.12),
      child: InkWell(
        onTap: answered ? null : () => _answer(k),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: edge ?? AppColors.gold.withValues(alpha: 0.16),
              ),
              child: edge != null
                  ? Icon(isRight ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 19)
                  : Text('أبجد'[k], style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(it.options[k], style: const TextStyle(fontSize: 16, height: 1.55, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }

  Widget _feedback(QuizItem it, Color hint) {
    final ok = _chosen == it.answer;
    final c = ok ? _right : _wrong;
    final title = ok ? 'أحسنت! إجابة صحيحة' : _chosen == -1 ? 'انتهى الوقت' : 'إجابة غير صحيحة';
    final last = _i + 1 == _items.length;
    return Card3D(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          if (!ok) ...[
            const SizedBox(height: 6),
            Text('الإجابة الصحيحة: ${it.options[it.answer]}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
          ],
          const SizedBox(height: 8),
          Text(it.q.explanation, style: const TextStyle(fontSize: 14.5, height: 1.85)),
          const SizedBox(height: 4),
          Text('المصدر: ${it.q.source}', style: TextStyle(fontSize: 12, color: hint)),
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('اقرأ المزيد'),
              onPressed: () => openQuizSource(context, it.q.ref),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: Icon(last ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 18),
              label: Text(last ? 'النتيجة' : 'التالي'),
              onPressed: _next,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _result(String name) {
    final total = _items.length;
    final stars = quizStars(_score, total);
    final best = widget.stats.best[widget.category] ?? _score;
    final hint = Theme.of(context).hintColor;
    final msg = switch (stars) {
      3 => 'ما شاء الله! نتيجة ممتازة',
      2 => 'أحسنت، نتيجة جيدة جدًا',
      1 => 'جيد، وبالمراجعة تزداد',
      _ => 'لا بأس، راجع المصادر وحاول مرة أخرى',
    };
    final wrong = [
      for (var k = 0; k < _items.length; k++)
        if (_answers[k] != _items[k].answer) _items[k],
    ];
    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        decoration: hero3D(radius: 24),
        child: Column(children: [
          _Stars(stars, size: 46),
          const SizedBox(height: 8),
          Text('${Arabic.digits(_score)} / ${Arabic.digits(total)}',
              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))])),
          Text(msg, style: TextStyle(color: AppColors.goldLight, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('مسابقة «$name»', style: TextStyle(color: AppColors.heroText)),
          if (_record) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
              child: Text('🏆 رقم قياسي جديد', style: TextStyle(color: AppColors.current.bg, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _ResultStat('الأفضل', '${Arabic.digits(best)}/${Arabic.digits(total)}'),
            _ResultStat('أطول تتابع', Arabic.digits(_bestRun)),
            _ResultStat('أيام متتالية', '🔥 ${Arabic.digits(widget.stats.streakOn(app.today))}'),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.replay_rounded),
              label: const Text('جولة أخرى'),
              onPressed: () => setState(_newRound),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة النتيجة'),
              onPressed: () => shareAsImage(
                context,
                title: 'مسابقات سبيل • $name',
                text: '${'★' * stars}${'☆' * (3 - stars)}\nأجبتُ عن ${Arabic.digits(_score)} من ${Arabic.digits(total)} أسئلة',
                ref: 'أسئلة من محتوى التطبيق مع مصادرها',
              ),
            ),
          ),
        ]),
      ),
      if (wrong.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text('راجع ما فاتك', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold, fontSize: 15)),
        ),
      for (final it in wrong)
        Card3D(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(it.q.question, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.6)),
            subtitle: Text('الإجابة: ${it.options[it.answer]}\n${it.q.source}', style: TextStyle(color: hint, height: 1.6)),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => openQuizSource(context, it.q.ref),
          ),
        ),
    ]);
  }
}

class _ResultStat extends StatelessWidget {
  final String label, value;
  const _ResultStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: AppColors.heroText, fontSize: 12)),
        ]),
      );
}

/// Opens the page of the app that the question was made from.
Future<void> openQuizSource(BuildContext context, QuizRef r) async {
  final nav = Navigator.of(context);
  void push(Widget page) => nav.push(MaterialPageRoute(builder: (_) => page));
  switch (r.src) {
    case 'prophets':
      final p = app.repo.prophets.where((p) => p.id == r.id).firstOrNull;
      if (p != null) push(ProphetPage(prophet: p));
    case 'ghazawat':
      final g = (await GhazawatData.load()).byId('${r.id}');
      if (g != null) push(GhazwaPage(g: g));
    case 'companions':
      final d = await CompanionsData.load();
      final c = d.list.where((c) => c.id == r.id).firstOrNull;
      if (c != null) push(CompanionPage(c: c, note: d.note));
    case 'companions_islam':
      push(const CompanionsIslamPage());
    case 'arbaeen':
      final book = await Arbaeen.load();
      final memo = await ArbaeenMemory.load();
      final i = book.hadiths.indexWhere((h) => h.number == r.n);
      if (i < 0) return;
      push(ArbaeenHadithPage(
        book: book,
        start: i,
        memorized: () => memo,
        onToggle: (n, v) {
          v ? memo.add(n) : memo.remove(n);
          ArbaeenMemory.save(memo);
        },
      ));
    case 'fiqh':
      final item = (await FiqhData.load()).items.where((i) => i.id == r.id).firstOrNull;
      if (item != null) {
        push(Scaffold(
          appBar: AppBar(title: const Text('فقه العبادات')),
          body: ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [FiqhCard(item: item)]),
        ));
      }
    case 'asma':
      push(const AsmaPage());
    case 'quran':
      if (r.n != null && context.mounted) openMushaf(context, app.mushaf.pageOf(r.n!, 1));
  }
}
