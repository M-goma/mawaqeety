import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/hifz.dart';
import '../main.dart';
import '../services/hifz.dart';
import 'ayah_sheet.dart';
import 'theme.dart';

String _times(int n) => n == 1 ? 'مرة' : n == 2 ? 'مرتان' : n <= 10 ? '${Arabic.digits(n)} مرات' : '${Arabic.digits(n)} مرة';

String _ayat(int n) {
  if (n == 1) return 'آية واحدة';
  if (n == 2) return 'آيتان';
  return n >= 3 && n <= 10 ? '${Arabic.digits(n)} آيات' : '${Arabic.digits(n)} آية';
}

String _days(int n) => n == 1 ? 'يوم' : n == 2 ? 'يومين' : n <= 10 ? '${Arabic.digits(n)} أيام' : '${Arabic.digits(n)} يومًا';

/// Letters that never join the next one (no tatweel after them).
const _nonJoining = 'اأإآٱءدذرزوؤة';

String rangeLabel(HifzRange r) {
  final name = app.repo.surahs[r.surah - 1].name;
  return r.from == r.to
      ? 'سورة $name • الآية ${Arabic.digits(r.from)}'
      : 'سورة $name • الآيات ${Arabic.digits(r.from)}–${Arabic.digits(r.to)}';
}

/// The Quran tab's card for the memorization helper (next to the khatma card).
class HifzCard extends StatelessWidget {
  const HifzCard({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.hifz,
      builder: (context, _) {
        final p = app.hifz.progress;
        final due = p.dueCount(app.today);
        final sub = p.entries.isEmpty
            ? 'كرّر الآيات بصوت القارئ، واختبر حفظك، وراجعه في موعده'
            : 'حفظت ${_ayat(p.memorized)}${due > 0 ? ' • ${_ayat(due)} للمراجعة اليوم' : ' • لا مراجعة اليوم'}';
        return Card3D(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: ListTile(
            leading: const Tile3D(size: 40, child: Text('🧠', style: TextStyle(fontSize: 19))),
            title: const Text('مساعد الحفظ', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (due > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                  child: Text(Arabic.digits(due), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              const Icon(Icons.chevron_left),
            ]),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => HifzPage(tab: due > 0 ? 2 : 0))),
          ),
        );
      },
    );
  }
}

/// مساعد الحفظ: repeat a range with a reciter, test yourself with hidden words, and review on schedule.
class HifzPage extends StatefulWidget {
  /// The range to start with (e.g. «احفظ هذه الآية» from the Mushaf); defaults to the last one used.
  final HifzRange? initial;
  final int tab;
  const HifzPage({super.key, this.initial, this.tab = 0});
  @override
  State<HifzPage> createState() => _HifzPageState();
}

class _HifzPageState extends State<HifzPage> with SingleTickerProviderStateMixin {
  HifzStore get store => app.hifz;
  HifzPlayer get player => app.hifzPlayer;
  late final _tabs = TabController(length: 3, vsync: this, initialIndex: widget.tab);
  late HifzRange _range = widget.initial ?? store.lastRange ?? _defaultRange();
  late int _testAyah = _range.from;
  final _revealed = <int>{};
  bool _allShown = false;
  final _keys = <int, GlobalKey>{};
  int _followed = 0;

  static HifzRange _defaultRange() {
    final l = app.settings.lastRead;
    if (l == null) return const HifzRange(1, 1, 7);
    final len = app.repo.surahs[l.surah - 1].verses.length;
    return HifzRange.clamped(l.surah, l.ayah, l.ayah + 4, len);
  }

  @override
  void initState() {
    super.initState();
    player.addListener(_follow);
    if (widget.initial != null) store.change((s) => s.lastRange = _range);
  }

  @override
  void dispose() {
    player.removeListener(_follow);
    player.stop();
    _tabs.dispose();
    super.dispose();
  }

  String get _reciter => store.reciter.isEmpty ? app.settings.reciterId : store.reciter;

  // Keep the ayah being recited in view.
  void _follow() {
    if (!mounted || !player.active || player.ayah == _followed) return;
    _followed = player.ayah;
    final c = _keys[player.ayah]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), alignment: 0.3);
  }

  void _setRange(HifzRange r) {
    if (player.active) player.stop();
    setState(() {
      _range = r;
      _testAyah = r.from;
      _revealed.clear();
      _allShown = false;
    });
    store.change((s) => s.lastRange = r);
  }

  void _play({int? from}) => player.play(_reciter, _range, each: store.each, rounds: store.rounds, startAt: from);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, player]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('مساعد الحفظ'),
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(icon: Icon(Icons.repeat_rounded), text: 'التكرار'),
            Tab(icon: Icon(Icons.visibility_off_outlined), text: 'اختبر نفسك'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'التقدّم'),
          ]),
        ),
        body: TabBarView(controller: _tabs, children: [_listenTab(), _testTab(), _progressTab()]),
      ),
    );
  }

  // ---------------- range ----------------
  Widget _rangeCard() {
    final s = app.repo.surahs[_range.surah - 1];
    Widget end(String label, int value, ValueChanged<int> onPick) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickAyah(label, value, s.verses.length, onPick),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Text(label, style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
                const Spacer(),
                Text(Arabic.digits(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: hero3D(radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickSurah,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Text('🧠', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('سورة ${s.name}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('${_ayat(_range.length)} من ${_ayat(s.verses.length)} • حفظت منها ${Arabic.digits(store.progress.memorizedIn(s.number))}',
                      style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.swap_vert_rounded, color: Colors.white70),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          end('من الآية', _range.from, (v) => _setRange(HifzRange.clamped(s.number, v, v > _range.to ? v : _range.to, s.verses.length))),
          const SizedBox(width: 8),
          end('إلى الآية', _range.to, (v) => _setRange(HifzRange.clamped(s.number, v < _range.from ? v : _range.from, v, s.verses.length))),
        ]),
      ]),
    );
  }

  void _pickSurah() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.75,
        child: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('اختر السورة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          for (final s in app.repo.surahs)
            ListTile(
              dense: true,
              selected: s.number == _range.surah,
              leading: Text(Arabic.digits(s.number), style: const TextStyle(fontWeight: FontWeight.w700)),
              title: Text('سورة ${s.name}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              subtitle: Text(_ayat(s.verses.length)),
              trailing: store.progress.memorizedIn(s.number) > 0
                  ? Text('حفظت ${Arabic.digits(store.progress.memorizedIn(s.number))}', style: TextStyle(color: AppColors.emerald))
                  : null,
              onTap: () {
                Navigator.pop(c);
                _setRange(HifzRange.clamped(s.number, 1, 5, s.verses.length));
              },
            ),
        ]),
      ),
    );
  }

  void _pickAyah(String title, int current, int count, ValueChanged<int> onPick) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * (count > 40 ? 0.7 : 0.45),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          Expanded(
            child: GridView.count(
              crossAxisCount: 6,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var a = 1; a <= count; a++)
                  ChoiceChip(
                    label: Text(Arabic.digits(a)),
                    selected: a == current,
                    showCheckmark: false,
                    onSelected: (_) {
                      Navigator.pop(c);
                      onPick(a);
                    },
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------- repeat ----------------
  Widget _listenTab() {
    final theme = Theme.of(context);
    final s = app.repo.surahs[_range.surah - 1];
    final mine = player.active && player.range == _range;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(t, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      _rangeCard(),
      Card3D(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('تكرار كل آية'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final n in HifzStore.eachChoices)
                  ChoiceChip(label: Text(_times(n)), selected: store.each == n, onSelected: (_) => _setEach(n)),
              ]),
            ),
            label('ثم تكرار المقطع كاملًا'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final n in HifzStore.roundChoices)
                  ChoiceChip(label: Text(_times(n)), selected: store.rounds == n, onSelected: (_) => _setRounds(n)),
              ]),
            ),
            const Divider(height: 22),
            ListTile(
              leading: const Tile3D(size: 38, child: Text('🎙️', style: TextStyle(fontSize: 18))),
              title: const Text('القارئ', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(app.repo.reciter(_reciter).name),
              trailing: const Icon(Icons.chevron_left),
              onTap: _pickReciter,
            ),
          ]),
        ),
      ),
      Card3D(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        color: mine ? AppColors.goldSoft : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: mine
              ? Row(children: [
                  Icon(Icons.graphic_eq, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الآية ${Arabic.digits(player.ayah)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('التكرار ${Arabic.digits(player.rep)} من ${Arabic.digits(player.each)}'
                          '${player.rounds > 1 ? ' • الدورة ${Arabic.digits(player.round)} من ${Arabic.digits(player.rounds)}' : ''}',
                          style: TextStyle(color: theme.hintColor, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton.filled(
                    tooltip: player.playing ? 'إيقاف مؤقت' : 'متابعة',
                    icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: player.togglePause,
                  ),
                  IconButton(tooltip: 'إيقاف', icon: const Icon(Icons.stop_rounded), onPressed: player.stop),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('ابدأ التكرار'),
                    onPressed: () => _play(),
                  ),
                  const SizedBox(height: 6),
                  Text('كل آية ${_times(store.each)} ثم التي تليها'
                      '${store.rounds > 1 ? '، والمقطع كله ${_times(store.rounds)}' : ''} • اضغط على آية للبدء منها',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  if (player.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(player.error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5)),
                    ),
                ]),
        ),
      ),
      for (final a in _range.ayat) _ayahTile(s.number, a, s.verses[a - 1], mine && player.ayah == a),
    ]);
  }

  Widget _ayahTile(int surah, int a, String text, bool current) {
    final e = store.progress.of(surah, a);
    final key = _keys.putIfAbsent(a, GlobalKey.new);
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: current ? AppColors.emerald.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current ? AppColors.emerald : Theme.of(context).dividerColor.withValues(alpha: 0.4), width: current ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _play(from: a),
        onLongPress: () => showAyahSheet(context, surah, a, hifz: false),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text('$text ﴿${Arabic.digits(a)}﴾',
                  style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 2.1, color: Theme.of(context).colorScheme.onSurface)),
            ),
            if (e != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 6),
                child: Icon(e.weak ? Icons.error_outline : Icons.check_circle, size: 18, color: e.weak ? AppColors.gold : AppColors.emerald),
              ),
          ]),
        ),
      ),
    );
  }

  void _setEach(int n) {
    store.change((s) => s.each = n);
    if (player.active) _play(from: player.ayah);
  }

  void _setRounds(int n) {
    store.change((s) => s.rounds = n);
    if (player.active) _play(from: player.ayah);
  }

  void _pickReciter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.6,
          child: ListView(children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('قارئ الحفظ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            for (final r in app.repo.reciters)
              ListTile(
                leading: Icon(r.id == _reciter ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.emerald),
                title: Text(r.name),
                onTap: () {
                  Navigator.pop(c);
                  store.change((s) => s.reciter = r.id);
                  if (player.active) _play(from: player.ayah);
                },
              ),
          ]),
        ),
      ),
    );
  }

  // ---------------- self-test ----------------
  Widget _testTab() {
    final theme = Theme.of(context);
    final s = app.repo.surahs[_range.surah - 1];
    final a = _testAyah.clamp(_range.from, _range.to);
    final words = ayahWords(s.verses[a - 1]);
    final done = _allShown || _revealed.length >= words.length;
    final e = store.progress.of(s.number, a);
    final status = e == null
        ? 'جديدة'
        : e.weak
            ? 'تحتاج مراجعة'
            : store.progress.isDue(e, app.today)
                ? 'محفوظة • موعد مراجعتها اليوم'
                : 'محفوظة • المراجعة بعد ${_days(e.due.difference(app.today).inDays)}';
    final hidden = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final quran = TextStyle(fontFamily: 'AmiriQuran', fontSize: 23, height: 1.9, color: theme.colorScheme.onSurface);
    Widget word(int i) {
      final w = words[i];
      final shown = _allShown || _revealed.contains(i);
      final (head, tail) = firstLetter(w);
      return GestureDetector(
        onTap: shown ? null : () => setState(() => _revealed.add(i)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: shown ? Colors.transparent : hidden,
            borderRadius: BorderRadius.circular(10),
            border: shown ? null : Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
          ),
          child: shown
              ? Text(w, style: quran)
              : store.firstLetters
                  // The first letter in its joining form (with a tatweel), over the word's own width.
                  ? Stack(children: [
                      Text(w, style: quran.copyWith(color: Colors.transparent)),
                      Positioned.fill(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(tail.isNotEmpty && !_nonJoining.contains(head[0]) ? '$headـ' : head,
                              style: quran.copyWith(color: AppColors.emerald)),
                        ),
                      ),
                    ])
                  : Text(w, style: quran.copyWith(color: Colors.transparent)),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      _rangeCard(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('إخفاء الكل'), icon: Icon(Icons.visibility_off_outlined)),
            ButtonSegment(value: true, label: Text('أول حرف من كل كلمة'), icon: Icon(Icons.text_fields_rounded)),
          ],
          selected: {store.firstLetters},
          showSelectedIcon: false,
          onSelectionChanged: (v) => store.change((s) => s.firstLetters = v.first),
        ),
      ),
      Card3D(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(
                tooltip: 'الآية السابقة',
                icon: const Icon(Icons.chevron_right),
                onPressed: a > _range.from ? () => _goTest(_range.step(a, -1)) : null,
              ),
              Expanded(
                child: Column(children: [
                  Text('الآية ${Arabic.digits(a)} (${Arabic.digits(a - _range.from + 1)} من ${Arabic.digits(_range.length)})',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(status, style: TextStyle(fontSize: 12, color: e?.weak ?? false ? AppColors.gold : theme.hintColor)),
                ]),
              ),
              IconButton(
                tooltip: 'استمع للآية',
                icon: Icon(Icons.headphones_rounded, color: AppColors.emerald),
                onPressed: () => player.play(_reciter, HifzRange(s.number, a, a), each: 1, rounds: 1),
              ),
              IconButton(
                tooltip: 'الآية التالية',
                icon: const Icon(Icons.chevron_left),
                onPressed: a < _range.to ? () => _goTest(_range.step(a, 1)) : null,
              ),
            ]),
            const Divider(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < words.length; i++) word(i),
                  Text('﴿${Arabic.digits(a)}﴾', style: quran.copyWith(color: AppColors.gold)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!done)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.touch_app_outlined),
                    label: const Text('الكلمة التالية'),
                    onPressed: () => setState(() {
                      final next = List.generate(words.length, (i) => i).firstWhere((i) => !_revealed.contains(i), orElse: () => 0);
                      _revealed.add(next);
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('أظهر الآية'),
                    onPressed: () => setState(() => _allShown = true),
                  ),
                ),
              ])
            else
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('أتقنتها'),
                    onPressed: () => _mark(s.number, a, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: BorderSide(color: AppColors.gold)),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('تحتاج مراجعة'),
                    onPressed: () => _mark(s.number, a, false),
                  ),
                ),
              ]),
            if (done)
              TextButton(onPressed: () => setState(() { _revealed.clear(); _allShown = false; }), child: const Text('أخفِها من جديد')),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Text('اقرأ الآية من حفظك، واضغط على أي كلمة لتظهرها إن توقفت. ثم قيّم نفسك: «أتقنتها» تضعها في جدول المراجعة '
            '(بعد يوم، ثم ٣، ثم ٧، ثم ١٤، ثم كل ٣٠ يومًا)، و«تحتاج مراجعة» تبقيها في قائمة اليوم.',
            style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.7)),
      ),
    ]);
  }

  void _goTest(int a) => setState(() {
        _testAyah = a;
        _revealed.clear();
        _allShown = false;
      });

  Future<void> _mark(int surah, int a, bool good) async {
    final messenger = ScaffoldMessenger.of(context);
    good ? await store.mastered(surah, a, app.today) : await store.needsReview(surah, a, app.today);
    if (!mounted) return;
    if (a < _range.to) {
      _goTest(a + 1);
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('أتممت ${rangeLabel(_range)} • بارك الله فيك')));
      setState(() {});
    }
  }

  // ---------------- progress ----------------
  Widget _progressTab() {
    final theme = Theme.of(context);
    final p = store.progress;
    final today = app.today;
    final due = p.dueRanges(today);
    final dueCount = p.dueCount(today);
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        padding: const EdgeInsets.all(18),
        decoration: hero3D(radius: 22),
        child: Row(children: [
          const Text('🌱', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حفظت ${_ayat(p.memorized)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('من ${Arabic.digits(6236)} آية • في ${Arabic.digits(p.surahs.length)} ${p.surahs.length >= 3 && p.surahs.length <= 10 ? 'سور' : 'سورة'}',
                  style: TextStyle(color: AppColors.heroText, fontSize: 13)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: p.memorized / 6236, minHeight: 7, color: AppColors.goldLight, backgroundColor: Colors.white24),
              ),
              const SizedBox(height: 6),
              Text(dueCount == 0 ? 'لا مراجعة اليوم' : '${_ayat(dueCount)} للمراجعة اليوم${p.weakCount > 0 ? ' • منها ${Arabic.digits(p.weakCount)} تحتاج مراجعة' : ''}',
                  style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text('للمراجعة اليوم', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ),
      if (due.isEmpty)
        Card3D(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: ListTile(
            leading: const Text('✅', style: TextStyle(fontSize: 22)),
            title: Text(p.entries.isEmpty ? 'لم تبدأ بعد' : 'أنهيت مراجعة اليوم'),
            subtitle: Text(p.entries.isEmpty
                ? 'اختر مقطعًا، وكرّره، ثم اختبر نفسك وقيّم حفظك ليظهر هنا في موعد مراجعته.'
                : 'تظهر الآيات هنا في موعد مراجعتها.'),
          ),
        )
      else
        for (final r in due)
          Card3D(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: ListTile(
              leading: Tile3D(size: 38, child: Icon(Icons.event_repeat_rounded, size: 20, color: AppColors.gold)),
              title: Text(rangeLabel(r), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_ayat(r.length)),
              trailing: FilledButton.tonal(onPressed: () => _review(r), child: const Text('راجع')),
              onTap: () => _review(r),
            ),
          ),
      if (p.surahs.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text('حفظك في السور', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Card3D(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(children: [
            for (final n in p.surahs)
              () {
                final s = app.repo.surahs[n - 1];
                final m = p.memorizedIn(n);
                return ListTile(
                  title: Row(children: [
                    Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${Arabic.digits(m)} / ${Arabic.digits(s.verses.length)}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                  ]),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(value: m / s.verses.length, minHeight: 6),
                    ),
                  ),
                  onTap: () => _review(HifzRange(n, 1, s.verses.length)),
                );
              }(),
          ]),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text('جدول المراجعة: تُراجَع الآية بعد يوم من إتقانها، ثم بعد ٣ أيام، ثم ٧، ثم ١٤، ثم كل ٣٠ يومًا. '
            'وإذا قيّمتها «تحتاج مراجعة» عادت إلى أول الجدول.',
            style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.7)),
      ),
    ]);
  }

  void _review(HifzRange r) {
    _setRange(r);
    _tabs.animateTo(1);
  }
}
