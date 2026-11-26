
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/arabic.dart';
import '../core/settings.dart';
import '../data/mushaf.dart';
import '../main.dart';
import 'quran_pages.dart';
import 'theme.dart';

/// Reading colours for the printed pages. The page images are grey-scale (white paper, black ink);
/// each tone maps paper → [bg] and ink → [fg].
class MushafTone {
  final String id, label;
  final Color bg, fg;
  final bool dark;
  const MushafTone(this.id, this.label, this.bg, this.fg, {this.dark = false});

  static const all = [
    MushafTone('paper', 'ورق كريمي', Color(0xFFFBF5E6), Color(0xFF1F1A14)),
    MushafTone('white', 'أبيض', Color(0xFFFFFFFF), Color(0xFF000000)),
    MushafTone('navy', 'ليلي كحلي', Color(0xFF121821), Color(0xFFECE0C4), dark: true),
    MushafTone('sepia', 'ليلي بنّي', Color(0xFF221B14), Color(0xFFF0E2C4), dark: true),
    MushafTone('charcoal', 'ليلي فحمي', Color(0xFF1E1E1E), Color(0xFFDCDCDC), dark: true),
  ];
  static MushafTone byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static MushafTone current(BuildContext context) {
    final s = app.settings;
    if (s.mushafMode != 'auto') return byId(s.mushafMode);
    return Theme.of(context).brightness == Brightness.dark ? byId(s.mushafNight) : byId('paper');
  }

  /// out = ink colour + (paper colour − ink colour) × grey.
  ColorFilter get filter {
    List<double> row(double b, double f) => [(b - f) / 255, 0, 0, 0, f];
    return ColorFilter.matrix([
      ...row(bg.r * 255, fg.r * 255),
      ...row(bg.g * 255, fg.g * 255),
      ...row(bg.b * 255, fg.b * 255),
      0, 0, 0, 1, 0,
    ]);
  }

  Color get muted => Color.lerp(fg, bg, 0.45)!;
}

void openMushaf(BuildContext context, int page, {bool replace = false}) {
  final route = MaterialPageRoute(builder: (_) => MushafPage(initialPage: page));
  replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
}

class MushafPage extends StatefulWidget {
  final int initialPage;
  const MushafPage({super.key, required this.initialPage});
  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  MushafIndex get idx => app.mushaf;
  late int _page = widget.initialPage.clamp(1, MushafIndex.pageCount);
  late final _ctrl = PageController(initialPage: _page - 1);
  bool _chrome = true;
  bool _zoomed = false;
  int _followed = 0;

  @override
  void initState() {
    super.initState();
    app.recitation.addListener(_onRecitation);
    _prefetch(_page);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _chrome) setState(() => _chrome = false);
    });
  }

  @override
  void dispose() {
    app.recitation.removeListener(_onRecitation);
    _ctrl.dispose();
    super.dispose();
  }

  void _prefetch(int p) {
    if (kIsWeb) return;
    for (final n in [p + 1, p - 1, p + 2]) {
      if (n >= 1 && n <= MushafIndex.pageCount) app.mushafStore.load(n);
    }
  }

  void _onPage(int i) {
    setState(() => _page = i + 1);
    _prefetch(_page);
    app.update((x) => x.mushafPage = _page, reschedule: false);
  }

  void _jump(int page, {bool animate = false}) {
    page = page.clamp(1, MushafIndex.pageCount);
    if (animate && (page - _page).abs() <= 2) {
      _ctrl.animateToPage(page - 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      _ctrl.jumpToPage(page - 1);
    }
  }

  // The page turns by itself with the recitation.
  void _onRecitation() {
    if (!mounted) return;
    final r = app.recitation;
    setState(() {});
    if (!r.active || r.surah < 1) return;
    final p = idx.pageOf(r.surah, r.ayah < 1 ? 1 : r.ayah);
    if (p != _followed) {
      _followed = p;
      if (r.ayah > 0) {
        final pos = Bookmark(r.surah, r.ayah);
        if (app.settings.lastRead != pos) app.update((x) => x.lastRead = pos, reschedule: false);
      }
      if (p != _page && !_zoomed) _jump(p, animate: true);
    }
  }

  void _play() {
    final r = app.recitation;
    if (r.active) {
      r.togglePause();
      return;
    }
    final (s, a) = idx.startOf(_page);
    startQuranRecitation(s, a);
  }

  bool get _readHere {
    final l = app.settings.lastRead;
    return l != null && idx.pageOf(l.surah, l.ayah) == _page;
  }

  void _toggleReadHere() {
    if (_readHere) {
      app.update((x) => x.lastRead = null, reschedule: false);
      _snack('تمت إزالة موضع القراءة');
    } else {
      final (s, a) = idx.startOf(_page);
      app.update((x) => x.lastRead = Bookmark(s, a), reschedule: false);
      _snack('تم حفظ موضع القراءة: صفحة ${Arabic.digits(_page)}');
    }
    setState(() {});
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));
  }

  void _pageMenu() {
    final (s, a) = idx.startOf(_page);
    final b = Bookmark(s, a);
    final marked = app.settings.bookmarks.contains(b);
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.play_circle_outline, color: AppColors.emerald),
            title: const Text('استماع من أول الصفحة'),
            onTap: () {
              Navigator.pop(c);
              startQuranRecitation(s, a);
            },
          ),
          ListTile(
            leading: Icon(_readHere ? Icons.bookmark_remove_outlined : Icons.bookmark_added_outlined),
            title: Text(_readHere ? 'إزالة موضع القراءة' : 'حفظ موضع القراءة هنا'),
            onTap: () {
              Navigator.pop(c);
              _toggleReadHere();
            },
          ),
          ListTile(
            leading: Icon(marked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
            title: Text(marked ? 'إزالة علامة الصفحة' : 'إضافة علامة على الصفحة'),
            onTap: () {
              app.update((x) => marked ? x.bookmarks.remove(b) : x.bookmarks.add(b), reschedule: false);
              Navigator.pop(c);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('عرض الصفحة نصًّا'),
            onTap: () {
              Navigator.pop(c);
              _toText();
            },
          ),
        ]),
      ),
    );
  }

  void _toText() {
    final (s, a) = idx.startOf(_page);
    app.update((x) => x.quranView = 'text', reschedule: false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surah: s, initialAyah: a)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final tone = MushafTone.current(context);
        final rec = app.recitation;
        final surah = app.repo.surahs[idx.surahOf(_page) - 1];
        final (hizb, quarter) = idx.hizbOf(_page);
        final info = TextStyle(color: tone.muted, fontSize: 13, fontWeight: FontWeight.w600);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: tone.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: tone.bg,
            bottomNavigationBar: rec.active ? _RecitationBar(tone: tone) : null,
            body: SafeArea(
              child: Stack(children: [
                Column(children: [
                  // Header like a printed Mushaf: surah on the right, juz and hizb on the left.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
                    child: Row(children: [
                      Text('سورة ${surah.name}', style: info),
                      const Spacer(),
                      Text('الجزء ${Arabic.digits(idx.juzOf(_page))} • ${_quarterLabel(quarter)}الحزب ${Arabic.digits(hizb)}', style: info),
                    ]),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _ctrl,
                      physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                      itemCount: MushafIndex.pageCount,
                      onPageChanged: _onPage,
                      itemBuilder: (context, i) => _PageImage(
                        page: i + 1,
                        tone: tone,
                        ribbon: () {
                          final l = app.settings.lastRead;
                          return l != null && idx.pageOf(l.surah, l.ayah) == i + 1;
                        }(),
                        onTap: () => setState(() => _chrome = !_chrome),
                        onLongPress: _pageMenu,
                        onZoom: (z) {
                          if (z != _zoomed) setState(() => _zoomed = z);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: Text(Arabic.digits(_page), style: info.copyWith(fontSize: 14)),
                  ),
                ]),
                // Optional dimming, independent of the phone's brightness.
                if (app.settings.mushafDim > 0)
                  IgnorePointer(child: Container(color: Colors.black.withValues(alpha: app.settings.mushafDim))),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  top: _chrome ? 0 : -80,
                  left: 0,
                  right: 0,
                  child: _Toolbar(
                    tone: tone,
                    playing: rec.active && rec.playing,
                    readHere: _readHere,
                    onIndex: _openIndex,
                    onReadHere: _toggleReadHere,
                    onPlay: _play,
                    onLook: _openLook,
                    onText: _toText,
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  static String _quarterLabel(int q) => const ['', 'ربع ', 'نصف ', 'ثلاثة أرباع '][q];

  void _openLook() => showModalBottomSheet(context: context, builder: (_) => const MushafLookSheet());

  void _openIndex() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.75,
        child: _IndexSheet(current: _page, onGo: (p) {
          Navigator.pop(c);
          _jump(p);
        }),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final MushafTone tone;
  final bool playing, readHere;
  final VoidCallback onIndex, onReadHere, onPlay, onLook, onText;
  const _Toolbar({required this.tone, required this.playing, required this.readHere, required this.onIndex,
      required this.onReadHere, required this.onPlay, required this.onLook, required this.onText});

  @override
  Widget build(BuildContext context) {
    final c = tone.fg;
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        color: Color.lerp(tone.bg, tone.fg, 0.07)!.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(children: [
        IconButton(tooltip: 'رجوع', icon: Icon(Icons.arrow_forward, color: c), onPressed: () => Navigator.maybePop(context)),
        const Spacer(),
        IconButton(tooltip: 'الفهرس', icon: Icon(Icons.list_alt, color: c), onPressed: onIndex),
        IconButton(
          tooltip: readHere ? 'إزالة موضع القراءة' : 'حفظ موضع القراءة',
          icon: Icon(readHere ? Icons.bookmark : Icons.bookmark_border, color: readHere ? AppColors.emerald : c),
          onPressed: onReadHere,
        ),
        IconButton(
          tooltip: playing ? 'إيقاف مؤقت' : 'استماع',
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.emerald, size: 32),
          onPressed: onPlay,
        ),
        IconButton(tooltip: 'المظهر والسطوع', icon: Icon(Icons.brightness_6_outlined, color: c), onPressed: onLook),
        IconButton(tooltip: 'عرض نصي', icon: Icon(Icons.notes, color: c), onPressed: onText),
      ]),
    );
  }
}

class _RecitationBar extends StatelessWidget {
  final MushafTone tone;
  const _RecitationBar({required this.tone});
  @override
  Widget build(BuildContext context) {
    final rec = app.recitation;
    final name = rec.surah > 0 ? app.repo.surahs[rec.surah - 1].name : '';
    return SafeArea(
      child: Container(
        color: AppColors.navy3,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(Icons.graphic_eq, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${app.repo.reciter(app.settings.reciterId).name} • $name ${rec.ayah == 0 ? 'البسملة' : 'آية ${Arabic.digits(rec.ayah)}'}',
                style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
          ),
          IconButton(
              tooltip: 'القارئ',
              icon: const Icon(Icons.record_voice_over_outlined, color: Colors.white),
              onPressed: () => showReciterPicker(context)),
          IconButton(icon: Icon(rec.playing ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: rec.togglePause),
          IconButton(icon: const Icon(Icons.stop, color: Colors.white), onPressed: rec.stop),
        ]),
      ),
    );
  }
}

/// One printed page, tinted with the reading colours, with pinch / double-tap zoom.
class _PageImage extends StatefulWidget {
  final int page;
  final MushafTone tone;
  final bool ribbon;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<bool> onZoom;
  const _PageImage({required this.page, required this.tone, required this.ribbon, required this.onTap,
      required this.onLongPress, required this.onZoom});
  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  final _tc = TransformationController();
  Future<Uint8List?>? _bytes;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _bytes = app.mushafStore.load(widget.page);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _bytes = app.mushafStore.load(widget.page));

  void _reportZoom() => widget.onZoom(_tc.value.getMaxScaleOnAxis() > 1.02);

  void _doubleTap() {
    if (_tc.value.getMaxScaleOnAxis() > 1.02) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.2;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    _reportZoom();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    Widget image(ImageProvider p) => ColorFiltered(
          colorFilter: tone.filter,
          child: Image(image: p, fit: BoxFit.contain, gaplessPlayback: true, filterQuality: FilterQuality.medium),
        );
    final Widget content = kIsWeb
        ? Image.network(app.mushaf.url(widget.page),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            color: null,
            frameBuilder: (c, child, frame, sync) =>
                frame == null ? _loading(tone) : ColorFiltered(colorFilter: tone.filter, child: child),
            errorBuilder: (c, e, s) => _failed(tone))
        : FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (c, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading(tone);
              final b = snap.data;
              if (b == null) return _failed(tone);
              return image(MemoryImage(b));
            },
          );
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 4,
        panEnabled: true,
        onInteractionEnd: (_) => _reportZoom(),
        child: Stack(children: [
          Positioned.fill(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Center(child: content)),
          ),
          if (widget.ribbon)
            PositionedDirectional(
              top: 0,
              start: 14,
              child: Icon(Icons.bookmark, color: AppColors.emerald, size: 30),
            ),
        ]),
      ),
    );
  }

  Widget _loading(MushafTone t) => Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: t.muted));

  Widget _failed(MushafTone t) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, color: t.muted, size: 40),
          const SizedBox(height: 8),
          Text('تعذّر تحميل الصفحة ${Arabic.digits(widget.page)}\nتأكد من الاتصال بالإنترنت', textAlign: TextAlign.center, style: TextStyle(color: t.fg)),
          const SizedBox(height: 8),
          if (!kIsWeb) OutlinedButton(onPressed: _retry, child: const Text('إعادة المحاولة')),
        ]),
      );
}

/// Colours and brightness of the Mushaf.
class MushafLookSheet extends StatelessWidget {
  const MushafLookSheet({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        Widget swatch(String id, String label, Color bg, Color fg) {
          final sel = s.mushafMode == id;
          return GestureDetector(
            onTap: () => app.update((x) {
              x.mushafMode = id;
              if (MushafTone.byId(id).dark && id != 'auto') x.mushafNight = id;
            }, reschedule: false),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52, height: 52, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg, shape: BoxShape.circle,
                  border: Border.all(color: sel ? AppColors.gold : Colors.grey.withValues(alpha: 0.4), width: sel ? 3 : 1),
                ),
                child: id == 'auto'
                    ? Icon(Icons.brightness_auto, color: fg)
                    : Text('بسم', style: TextStyle(fontFamily: 'AmiriQuran', color: fg, fontSize: 15, height: 1.2)),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ألوان المصحف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 10, children: [
                swatch('auto', 'تلقائي', Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.onSurface),
                for (final t in MushafTone.all) swatch(t.id, t.label, t.bg, t.fg),
              ]),
              if (s.mushafMode == 'auto')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('نهارًا: ورق كريمي • ليلًا: ${MushafTone.byId(s.mushafNight).label} (حسب وضع التطبيق)',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ),
              const SizedBox(height: 18),
              Row(children: [
                const Icon(Icons.brightness_low, size: 20),
                Expanded(
                  child: Slider(
                    min: 0, max: 0.6, divisions: 12,
                    value: 0.6 - s.mushafDim,
                    label: '${((1 - s.mushafDim) * 100).round()}٪',
                    onChanged: (v) => app.update((x) => x.mushafDim = double.parse((0.6 - v).toStringAsFixed(2)), reschedule: false),
                  ),
                ),
                const Icon(Icons.brightness_high, size: 20),
              ]),
              Text('سطوع الصفحة (لا يغيّر سطوع الهاتف)', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ]),
          ),
        );
      },
    );
  }
}

class _IndexSheet extends StatefulWidget {
  final int current;
  final ValueChanged<int> onGo;
  const _IndexSheet({required this.current, required this.onGo});
  @override
  State<_IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<_IndexSheet> {
  late double _p = widget.current.toDouble();

  @override
  Widget build(BuildContext context) {
    final idx = app.mushaf;
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'الصفحات')]),
        Expanded(
          child: TabBarView(children: [
            ListView(children: [
              for (final s in app.repo.surahs)
                ListTile(
                  dense: true,
                  selected: idx.surahOf(widget.current) == s.number,
                  leading: Text(Arabic.digits(s.number), style: const TextStyle(fontWeight: FontWeight.w700)),
                  title: Text('سورة ${s.name}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  trailing: Text('ص ${Arabic.digits(idx.pageOf(s.number, 1))}'),
                  onTap: () => widget.onGo(idx.pageOf(s.number, 1)),
                ),
            ]),
            ListView(children: [
              for (var j = 1; j <= 30; j++)
                ListTile(
                  dense: true,
                  selected: idx.juzOf(widget.current) == j,
                  leading: Text(Arabic.digits(j), style: const TextStyle(fontWeight: FontWeight.w700)),
                  title: Text('الجزء ${Arabic.digits(j)}', style: const TextStyle(fontSize: 15.5)),
                  subtitle: Text('يبدأ من سورة ${app.repo.surahs[idx.surahOf(idx.juzStartPage(j)) - 1].name}'),
                  trailing: Text('ص ${Arabic.digits(idx.juzStartPage(j))}'),
                  onTap: () => widget.onGo(idx.juzStartPage(j)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text('صفحة ${Arabic.digits(_p.round())}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                Text('سورة ${app.repo.surahs[idx.surahOf(_p.round()) - 1].name} • الجزء ${Arabic.digits(idx.juzOf(_p.round()))}'),
                Slider(min: 1, max: 604, divisions: 603, value: _p, onChanged: (v) => setState(() => _p = v)),
                FilledButton(onPressed: () => widget.onGo(_p.round()), child: const Text('اذهب إلى الصفحة')),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
