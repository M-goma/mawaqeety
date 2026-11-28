import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/prayer_calculator.dart';
import '../data/planner.dart';
import '../main.dart';
import '../services/tracker.dart' show dayKey;
import 'format.dart';
import 'theme.dart';

const _weekDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// «مخطط اليوم»: tasks placed automatically around the prayer times, with reminders and a daily summary.
class PlannerPage extends StatefulWidget {
  /// 0 = the day's timeline, 1 = the task list, 2 = the summary.
  final int initialTab;
  const PlannerPage({super.key, this.initialTab = 0});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

/// A minute of the day as a clock time («٥:٣٠ م»).
String planTime(int minute) {
  final m = minute % (24 * 60);
  return fmtTime(DateTime(2000, 1, 1, m ~/ 60, m % 60), app.settings.use24h);
}

/// A length of time: «٤٥ د»، «١ س ٣٠ د».
String planDuration(int m) {
  if (m < 60) return '${Arabic.digits(m)} د';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${Arabic.digits(h)} س' : '${Arabic.digits(h)} س ${Arabic.digits(r)} د';
}

String planTasks(int n) => n == 1 ? 'مهمة واحدة' : (n == 2 ? 'مهمتان' : (n >= 3 && n <= 10 ? '${Arabic.digits(n)} مهام' : '${Arabic.digits(n)} مهمة'));

class _PlannerPageState extends State<PlannerPage> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  int _offset = 0; // days after today

  DateTime get _date => app.today.add(Duration(days: _offset));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مخطط اليوم'),
        actions: [
          IconButton(tooltip: 'إعدادات المخطط', icon: const Icon(Icons.tune), onPressed: () => _settingsSheet(context)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'جدول اليوم'), Tab(text: 'المهام'), Tab(text: 'الملخص')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'مهمة جديدة',
        onPressed: () => showTaskSheet(context, date: _date),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([app, app.planner]),
        builder: (context, _) => TabBarView(controller: _tabs, children: [
          _timeline(context),
          _list(context),
          const _Summary(),
        ]),
      ),
    );
  }

  Widget _dayBar(BuildContext context) {
    final d = _date;
    final label = _offset == 0 ? 'اليوم' : (_offset == 1 ? 'غدًا' : _weekDays[d.weekday - 1]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _offset > 0 ? () => setState(() => _offset--) : null,
        ),
        Expanded(
          child: Column(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${fmtGregorian(d)} • ${app.hijri(d)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _offset < 6 ? () => setState(() => _offset++) : null,
        ),
      ]),
    );
  }

  // ---------------- timeline ----------------
  Widget _timeline(BuildContext context) {
    final plan = app.planner.plan(_date);
    final theme = Theme.of(context);
    final isToday = _offset == 0;
    final now = app.now.hour * 60 + app.now.minute;
    final st = PlanStat.of(app.planner.of(_date));
    final rows = <Widget>[];
    var cursor = plan.dayStart;
    var nowShown = !isToday || now < plan.dayStart || now > plan.dayEnd;
    void showNow(int before) {
      if (!nowShown && now <= before) {
        rows.add(_NowMarker(now));
        nowShown = true;
      }
    }

    for (final b in plan.blocks) {
      if (b.start - cursor >= 15) {
        showNow(b.start);
        rows.add(_FreeRow(cursor, b.start));
      }
      showNow(b.start);
      rows.add(b.isPrayer ? _PrayerRow(b, friday: _date.weekday == DateTime.friday) : _TaskRow(b, date: _date));
      if (b.end > cursor) cursor = b.end;
    }
    if (plan.dayEnd - cursor >= 15) {
      showNow(plan.dayEnd);
      rows.add(_FreeRow(cursor, plan.dayEnd));
    }
    showNow(24 * 60 * 2);

    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      _dayBar(context),
      _QuickAdd(date: _date),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Row(children: [
          Expanded(
            child: Text(
              st.total == 0
                  ? 'من ${planTime(plan.dayStart)} إلى ${planTime(plan.dayEnd)} • الصلوات محجوزة'
                  : '${planTasks(st.total)} • ${planDuration(app.planner.of(_date).fold(0, (a, t) => a + t.minutes))}',
              style: TextStyle(fontSize: 12.5, color: theme.hintColor),
            ),
          ),
          FilledButton.icon(
            onPressed: st.total == 0
                ? null
                : () {
                    app.planner.arrange(_date);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رُتّب يومك حول الصلوات')));
                  },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('رتّب يومي'),
          ),
        ]),
      ),
      ...rows,
      if (plan.overflow.isNotEmpty) _Overflow(plan.overflow),
    ]);
  }

  // ---------------- list ----------------
  Widget _list(BuildContext context) {
    final plan = app.planner.plan(_date);
    final starts = {for (final b in plan.taskBlocks) b.task!.id: b.start};
    final tasks = app.planner.of(_date)
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        final x = starts[a.id] ?? 99999, y = starts[b.id] ?? 99999;
        return x != y ? x.compareTo(y) : a.priority.index.compareTo(b.priority.index);
      });
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      _dayBar(context),
      _QuickAdd(date: _date),
      if (tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text('لا مهام لهذا اليوم بعد.\nأضف مهمة وسيضعها المخطط في وقت فراغك بين الصلوات.',
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, height: 1.8)),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Text('اسحب المهمة لإنجازها أو حذفها', style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
        ),
        for (final t in tasks) _SwipeTask(t, start: starts[t.id], key: ValueKey(t.id)),
      ],
    ]);
  }
}

/// A one-line bar to add a task quickly (30 minutes, «عادي»; details can be edited after).
class _QuickAdd extends StatefulWidget {
  final DateTime date;
  const _QuickAdd({required this.date});
  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add() {
    final title = _ctl.text.trim();
    if (title.isEmpty) return;
    app.planner.add(PlanTask(id: newTaskId(), title: title, date: dayKey(widget.date)));
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(hintText: 'أضف مهمة سريعة…', prefixIcon: Icon(Icons.add_task)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'تفاصيل',
            onPressed: () {
              final title = _ctl.text.trim();
              _ctl.clear();
              showTaskSheet(context, date: widget.date, title: title);
            },
            icon: const Icon(Icons.edit_note),
          ),
        ]),
      );
}

String newTaskId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class PriorityChip extends StatelessWidget {
  final TaskPriority p;
  final bool small;
  const PriorityChip(this.p, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = Color(p.color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 1 : 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        border: Border.all(color: c.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(p.label, style: TextStyle(fontSize: small ? 10.5 : 12, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

Widget _pill(BuildContext context, String text, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).hintColor).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, color: color ?? Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
    );

/// Time column + rail + content, the shape of every timeline row.
class _Rail extends StatelessWidget {
  final String? from, to;
  final Color dot;
  final Widget child;
  final bool hollow;
  const _Rail({this.from, this.to, required this.dot, required this.child, this.hollow = false});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    // The rail's line is drawn behind the row (no IntrinsicHeight: it mis-measures wrapped chips).
    return Stack(children: [
      PositionedDirectional(
        top: 0,
        bottom: 0,
        start: 62 + 8,
        child: Container(width: 2, color: hint.withValues(alpha: 0.25)),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 62,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (from != null) Text(from!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              if (to != null) Text(to!, style: TextStyle(fontSize: 10, color: hint)),
            ]),
          ),
        ),
        SizedBox(
          width: 18,
          child: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: hollow ? Theme.of(context).scaffoldBackgroundColor : dot,
                  border: Border.all(color: dot, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ]),
    ]);
  }
}

class _PrayerRow extends StatelessWidget {
  final PlanBlock b;
  final bool friday;
  const _PrayerRow(this.b, {required this.friday});
  @override
  Widget build(BuildContext context) {
    final p = b.prayer!;
    final name = friday && p == Prayer.dhuhr ? 'الجمعة' : p.nameAr;
    return _Rail(
      from: planTime(b.start),
      to: planTime(b.end),
      dot: AppColors.gold,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: hero3D(radius: 16),
        child: Row(children: [
          Icon(Icons.mosque, color: AppColors.goldLight, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('صلاة $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Text(planDuration(b.end - b.start), style: TextStyle(color: AppColors.heroText, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  final int from, to;
  const _FreeRow(this.from, this.to);
  @override
  Widget build(BuildContext context) => _Rail(
        dot: Theme.of(context).hintColor.withValues(alpha: 0.5),
        hollow: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 11, 16, 11),
          child: Text('وقت متاح • ${planDuration(to - from)}  (${planTime(from)} – ${planTime(to)})',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ),
      );
}

class _NowMarker extends StatelessWidget {
  final int now;
  const _NowMarker(this.now);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('الآن', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.emerald)),
            ),
          ),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle)),
          Expanded(child: Container(height: 2, margin: const EdgeInsets.only(left: 16), color: AppColors.emerald)),
        ]),
      );
}

class _TaskRow extends StatelessWidget {
  final PlanBlock b;
  final DateTime date;
  const _TaskRow(this.b, {required this.date});
  @override
  Widget build(BuildContext context) {
    final t = b.task!;
    final c = Color(t.priority.color);
    return _Rail(
      from: planTime(b.start),
      to: planTime(b.end),
      dot: c,
      hollow: t.done,
      child: _TaskCard(t, start: b.start, clash: b.clash, margin: const EdgeInsets.fromLTRB(4, 4, 16, 4)),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final PlanTask t;
  final int? start;
  final bool clash;
  final EdgeInsetsGeometry margin;
  const _TaskCard(this.t, {this.start, this.clash = false, this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4)});
  @override
  Widget build(BuildContext context) {
    final c = Color(t.priority.color);
    final theme = Theme.of(context);
    return Card3D(
      margin: margin,
      radius: 14,
      child: InkWell(
        onTap: () => showTaskSheet(context, task: t),
        child: Container(
          decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: c, width: 4))),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    color: t.done ? theme.hintColor : null,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(spacing: 5, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  PriorityChip(t.priority, small: true),
                  _pill(context, '⏱ ${planDuration(t.minutes)}'),
                  if (t.fixedStart != null) _pill(context, '📌 ${planTime(t.fixedStart!)}'),
                  if (t.category != null) _pill(context, '${t.category!.emoji} ${t.category!.label}'),
                  if (t.remind != null) _pill(context, '🔔 ${t.remind == 0 ? 'عند البدء' : 'قبل ${Arabic.digits(t.remind!)} د'}'),
                  if (t.carried) _pill(context, '↩ مؤجلة من أمس', color: AppColors.gold),
                  if (clash) _pill(context, '⚠ يتعارض مع صلاة أو مهمة', color: const Color(0xFFE5484D)),
                ]),
              ]),
            ),
            Checkbox(value: t.done, onChanged: (v) => app.planner.setDone(t, v ?? false)),
          ]),
        ),
      ),
    );
  }
}

class _SwipeTask extends StatelessWidget {
  final PlanTask t;
  final int? start;
  const _SwipeTask(this.t, {this.start, super.key});
  @override
  Widget build(BuildContext context) {
    Widget bg(Color c, IconData icon, String label, AlignmentGeometry a) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: a,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        );
    return Dismissible(
      key: ValueKey('swipe-${t.id}'),
      background: bg(const Color(0xFF22A06B), t.done ? Icons.undo : Icons.check, t.done ? 'لم تُنجز' : 'أنجزتها',
          AlignmentDirectional.centerStart),
      secondaryBackground: bg(const Color(0xFFE5484D), Icons.delete_outline, 'حذف', AlignmentDirectional.centerEnd),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await app.planner.setDone(t, !t.done);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _deleteWithUndo(context, t),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          _TaskCard(t, start: start),
          if (start != null)
            PositionedDirectional(
              end: 64,
              top: 10,
              child: Text(planTime(start!), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ),
        ]),
        if (t.carried && !t.done)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextButton.icon(
                onPressed: () => _deleteWithUndo(context, t),
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('إسقاطها', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
      ]),
    );
  }
}

void _deleteWithUndo(BuildContext context, PlanTask t) {
  app.planner.remove(t);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('حُذفت «${t.title}»'),
      action: SnackBarAction(label: 'تراجع', onPressed: () => app.planner.add(t)),
    ));
}

class _Overflow extends StatelessWidget {
  final List<PlanTask> tasks;
  const _Overflow(this.tasks);
  @override
  Widget build(BuildContext context) => Card3D(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('لم يتسع لها اليوم (${Arabic.digits(tasks.length)})', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold))),
            ]),
            const SizedBox(height: 4),
            for (final t in tasks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(planDuration(t.minutes)),
                trailing: PriorityChip(t.priority, small: true),
                onTap: () => showTaskSheet(context, task: t),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => app.planner.moveToTomorrow(tasks),
                icon: const Icon(Icons.east),
                label: const Text('انقلها إلى الغد'),
              ),
            ),
          ]),
        ),
      );
}

// ---------------- summary ----------------
class _Summary extends StatelessWidget {
  const _Summary();
  @override
  Widget build(BuildContext context) {
    final pl = app.planner;
    final today = app.today;
    final st = pl.statOf(today);
    final theme = Theme.of(context);
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final weekStats = [for (final d in week) pl.statOf(d)];
    final weekMinutes = weekStats.fold(0, (a, s) => a + s.minutes);
    final weekDone = weekStats.fold(0, (a, s) => a + s.done);
    final byPriority = {for (final p in TaskPriority.values) p: pl.of(today).where((t) => t.priority == p).toList()};
    return ListView(padding: const EdgeInsets.fromLTRB(4, 8, 4, 96), children: [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        padding: const EdgeInsets.all(16),
        decoration: hero3D(radius: 22),
        child: Row(children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(value: st.ratio, strokeWidth: 9, color: AppColors.goldLight, backgroundColor: Colors.white24),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${Arabic.digits((st.ratio * 100).round())}٪', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                Text('اليوم', style: TextStyle(color: AppColors.heroText, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.total == 0 ? 'لا مهام اليوم بعد' : 'أنجزت ${Arabic.digits(st.done)} من ${planTasks(st.total)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text('⏱ ${planDuration(st.minutes)} من التركيز اليوم', style: TextStyle(color: AppColors.heroText, fontSize: 13)),
              Text('📅 ${planDuration(weekMinutes)} في آخر ٧ أيام', style: TextStyle(color: AppColors.heroText, fontSize: 13)),
              Text('✅ ${planTasks(weekDone)} منجزة هذا الأسبوع', style: TextStyle(color: AppColors.heroText, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      Card3D(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إنجاز الأسبوع', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('نسبة المهام المنجزة كل يوم، ودقائق التركيز تحتها', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 7; i++) _WeekBar(weekStats[i], _weekDays[week[i].weekday - 1], i == 6),
              ]),
            ),
          ]),
        ),
      ),
      Card3D(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مهام اليوم حسب الأولوية', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final p in TaskPriority.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 112, child: Align(alignment: AlignmentDirectional.centerStart, child: PriorityChip(p, small: true))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: byPriority[p]!.isEmpty ? 0 : byPriority[p]!.where((t) => t.done).length / byPriority[p]!.length,
                        minHeight: 8,
                        color: Color(p.color),
                        backgroundColor: Color(p.color).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('${Arabic.digits(byPriority[p]!.where((t) => t.done).length)}/${Arabic.digits(byPriority[p]!.length)}',
                        textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5)),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text('المهام محفوظة على جهازك فقط، وتُضمَّن في النسخة الاحتياطية.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.hintColor)),
      ),
    ]);
  }
}

class _WeekBar extends StatelessWidget {
  final PlanStat s;
  final String label;
  final bool isToday;
  const _WeekBar(this.s, this.label, this.isToday);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(s.total > 0 ? '${Arabic.digits((s.ratio * 100).round())}٪' : '', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 2),
          Container(
            height: 6 + 86 * s.ratio,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.emerald, AppColors.emerald.withValues(alpha: 0.6)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
              style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
          Text(s.minutes > 0 ? '${Arabic.digits(s.minutes)}د' : '–', style: TextStyle(fontSize: 9.5, color: AppColors.gold)),
        ]),
      );
}

// ---------------- task editor ----------------
/// Adds a task to [date] (or edits [task]) in a bottom sheet.
Future<void> showTaskSheet(BuildContext context, {PlanTask? task, DateTime? date, String title = ''}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _TaskSheet(task: task, date: date ?? app.today, title: title),
    );

class _TaskSheet extends StatefulWidget {
  final PlanTask? task;
  final DateTime date;
  final String title;
  const _TaskSheet({this.task, required this.date, this.title = ''});
  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final _title = TextEditingController(text: widget.task?.title ?? widget.title);
  late final _notes = TextEditingController(text: widget.task?.notes ?? '');
  late final _custom = TextEditingController();
  late int _minutes = widget.task?.minutes ?? 30;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.normal;
  late TaskCategory? _category = widget.task?.category;
  late int? _fixed = widget.task?.fixedStart;
  late int? _remind = widget.task == null ? 0 : widget.task!.remind;
  late bool _customOn = !plannerDurations.contains(_minutes);

  @override
  void initState() {
    super.initState();
    if (_customOn) _custom.text = '$_minutes';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_customOn) {
      final m = int.tryParse(Arabic.latinDigits(_custom.text.trim()));
      if (m != null && m >= 5) _minutes = m.clamp(5, 16 * 60);
    }
    final t = widget.task;
    if (t == null) {
      app.planner.add(PlanTask(
        id: newTaskId(),
        title: title,
        date: dayKey(widget.date),
        minutes: _minutes,
        priority: _priority,
        category: _category,
        fixedStart: _fixed,
        notes: _notes.text.trim(),
        remind: _remind,
      ));
    } else {
      t
        ..title = title
        ..minutes = _minutes
        ..priority = _priority
        ..category = _category
        ..fixedStart = _fixed
        ..notes = _notes.text.trim()
        ..remind = _remind;
      app.planner.edited(t);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(s, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.gold)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.task == null ? 'مهمة جديدة' : 'تعديل المهمة',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            autofocus: widget.task == null && widget.title.isEmpty,
            decoration: const InputDecoration(hintText: 'عنوان المهمة'),
          ),
          label('المدة المتوقعة'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in plannerDurations)
              ChoiceChip(
                label: Text(planDuration(m)),
                selected: !_customOn && _minutes == m,
                onSelected: (_) => setState(() {
                  _customOn = false;
                  _minutes = m;
                }),
              ),
            ChoiceChip(label: const Text('مخصص'), selected: _customOn, onSelected: (_) => setState(() => _customOn = true)),
          ]),
          if (_customOn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _custom,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'عدد الدقائق', suffixText: 'دقيقة'),
              ),
            ),
          label('الأولوية'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in TaskPriority.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _priority == p,
                selectedColor: Color(p.color),
                avatar: _priority == p ? null : CircleAvatar(backgroundColor: Color(p.color), radius: 5),
                onSelected: (_) => setState(() => _priority = p),
              ),
          ]),
          label('التصنيف'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in TaskCategory.values)
              ChoiceChip(
                label: Text('${c.emoji} ${c.label}'),
                selected: _category == c,
                onSelected: (v) => setState(() => _category = v ? c : null),
              ),
          ]),
          label('الوقت'),
          Row(children: [
            Expanded(
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('تلقائي'), icon: Icon(Icons.auto_awesome, size: 16)),
                  ButtonSegment(value: true, label: Text('وقت محدد'), icon: Icon(Icons.push_pin_outlined, size: 16)),
                ],
                selected: {_fixed != null},
                onSelectionChanged: (v) async {
                  if (!v.first) return setState(() => _fixed = null);
                  final now = app.now;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _fixed != null ? TimeOfDay(hour: _fixed! ~/ 60, minute: _fixed! % 60) : TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
                  );
                  if (picked != null) setState(() => _fixed = picked.hour * 60 + picked.minute);
                },
              ),
            ),
          ]),
          if (_fixed != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('تبدأ ${planTime(_fixed!)} وتنتهي ${planTime(_fixed! + _minutes)}', style: TextStyle(fontSize: 12.5, color: theme.hintColor)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('يضعها المخطط في أول فراغ يتسع لها بين الصلوات', style: TextStyle(fontSize: 12.5, color: theme.hintColor)),
            ),
          label('التذكير'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: const Text('بلا تذكير'), selected: _remind == null, onSelected: (_) => setState(() => _remind = null)),
            for (final r in plannerReminders)
              ChoiceChip(
                label: Text(r == 0 ? 'عند البدء' : 'قبل ${Arabic.digits(r)} د'),
                selected: _remind == r,
                onSelected: (_) => setState(() => _remind = r),
              ),
          ]),
          label('ملاحظات'),
          TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: 'اختياري')),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.task != null)
              TextButton.icon(
                onPressed: () {
                  final t = widget.task!;
                  Navigator.pop(context);
                  _deleteWithUndo(context, t);
                },
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE5484D)),
                label: const Text('حذف', style: TextStyle(color: Color(0xFFE5484D))),
              ),
            const Spacer(),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ')),
          ]),
        ]),
      ),
    );
  }
}

// ---------------- settings ----------------
Future<void> _settingsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ListenableBuilder(
        listenable: app.planner,
        builder: (context, _) {
          final c = app.planner.config;
          final fajr = app.prayerMinutes(app.today)[Prayer.fajr]!;
          Future<int?> pick(int m) async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60));
            return t == null ? null : t.hour * 60 + t.minute;
          }

          return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 20), children: [
            const Center(child: Text('إعدادات المخطط', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
            ListTile(
              leading: const Icon(Icons.wb_twilight),
              title: const Text('بداية اليوم'),
              subtitle: Text(c.dayStart == null ? 'من الفجر (${planTime(fajr)})' : planTime(c.dayStart!)),
              trailing: c.dayStart == null
                  ? null
                  : TextButton(onPressed: () => app.planner.setConfig((x) => x.dayStart = null), child: const Text('من الفجر')),
              onTap: () async {
                final m = await pick(c.dayStart ?? fajr);
                if (m != null) await app.planner.setConfig((x) => x.dayStart = m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('نهاية اليوم (وقت النوم)'),
              subtitle: Text(planTime(c.dayEnd)),
              onTap: () async {
                final m = await pick(c.dayEnd);
                if (m != null) await app.planner.setConfig((x) => x.dayEnd = m < 3 * 60 ? m + 24 * 60 : m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mosque_outlined),
              title: Text('وقت كل صلاة: ${Arabic.minutes(c.buffer)}'),
              subtitle: Slider(
                value: c.buffer.toDouble(),
                min: 10,
                max: 45,
                divisions: 7,
                label: Arabic.digits(c.buffer),
                onChanged: (v) => app.planner.setConfig((x) => x.buffer = v.round()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text('صلاة الجمعة: ${Arabic.minutes(c.jumuaBuffer)}'),
              subtitle: Slider(
                value: c.jumuaBuffer.toDouble(),
                min: 30,
                max: 120,
                divisions: 6,
                label: Arabic.digits(c.jumuaBuffer),
                onChanged: (v) => app.planner.setConfig((x) => x.jumuaBuffer = v.round()),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.redo),
              title: const Text('ترحيل ما لم يُنجز إلى الغد'),
              value: c.carryOver,
              onChanged: (v) => app.planner.setConfig((x) => x.carryOver = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('تذكير بالمهام'),
              subtitle: const Text('حسب التذكير الذي تختاره لكل مهمة'),
              value: c.reminders,
              onChanged: (v) => app.planner.setConfig((x) => x.reminders = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wb_sunny_outlined),
              title: const Text('خطة يومك بعد الفجر'),
              value: c.morningNote,
              onChanged: (v) => app.planner.setConfig((x) => x.morningNote = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.nights_stay_outlined),
              title: const Text('ملخص يومك بعد العشاء'),
              value: c.eveningNote,
              onChanged: (v) => app.planner.setConfig((x) => x.eveningNote = v),
            ),
          ]);
        },
      ),
    );

/// Home tab: the next task and today's progress, or an invitation to plan the day.
class PlannerHomeCard extends StatelessWidget {
  const PlannerHomeCard({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app, app.planner]),
        builder: (context, _) {
          final theme = Theme.of(context);
          final st = app.planner.statOf(app.today);
          void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerPage()));
          if (st.total == 0) {
            return Card3D(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: InkWell(
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Text('🗒️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('ابدأ تخطيط يومك حول الصلوات',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.gold)),
                    ),
                    Icon(Icons.chevron_left, color: theme.hintColor),
                  ]),
                ),
              ),
            );
          }
          final next = app.planner.nextBlock();
          final now = app.now.hour * 60 + app.now.minute;
          return Card3D(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: InkWell(
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text('🗒️ مهام اليوم', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const Spacer(),
                    Text('${Arabic.digits(st.done)}/${Arabic.digits(st.total)} • مخطط اليوم ›', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                  ]),
                  const SizedBox(height: 6),
                  if (next == null)
                    Text(st.done == st.total ? 'أنجزت مهام اليوم كلها، بارك الله في وقتك 🤍' : 'ما بقي لم يتسع له اليوم: انقله إلى الغد',
                        style: const TextStyle(fontSize: 13.5))
                  else
                    Row(children: [
                      Container(width: 4, height: 34, decoration: BoxDecoration(color: Color(next.task!.priority.color), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(next.task!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          Text(
                            '${next.start <= now ? 'الآن' : 'التالية'} • ${planTime(next.start)} – ${planTime(next.end)} • ${planDuration(next.task!.minutes)}',
                            style: TextStyle(fontSize: 11.5, color: theme.hintColor),
                          ),
                        ]),
                      ),
                      Checkbox(value: false, onChanged: (_) => app.planner.setDone(next.task!, true)),
                    ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: st.ratio, minHeight: 6, color: AppColors.emerald, backgroundColor: AppColors.emerald.withValues(alpha: 0.15)),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// Statistics page: today's planner progress and the week's focused time.
class PlannerStatsCard extends StatelessWidget {
  const PlannerStatsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final pl = app.planner;
    final today = app.today;
    final st = pl.statOf(today);
    var minutes = 0;
    for (var i = 0; i < 7; i++) {
      minutes += pl.statOf(today.subtract(Duration(days: i))).minutes;
    }
    return Card3D(
      child: ListTile(
        leading: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: st.ratio, strokeWidth: 4, color: AppColors.emerald, backgroundColor: AppColors.emerald.withValues(alpha: 0.15))),
            Text('${Arabic.digits((st.ratio * 100).round())}٪', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        title: Text(st.total == 0 ? 'مخطط اليوم: لا مهام اليوم' : 'مخطط اليوم: ${Arabic.digits(st.done)} من ${planTasks(st.total)}'),
        subtitle: Text('${planDuration(minutes)} من التركيز في آخر ٧ أيام'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerPage(initialTab: 2))),
      ),
    );
  }
}
