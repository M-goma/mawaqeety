import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../data/repository.dart';
import '../main.dart';
import '../services/narration.dart';
import 'format.dart';
import 'quran_pages.dart';
import 'theme.dart';

class ProphetsPage extends StatelessWidget {
  const ProphetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = app.repo.prophets;
    final st = app.stories;
    return ListenableBuilder(
      listenable: Listenable.merge([app, st]),
      builder: (context, _) {
        final voice = app.settings.narrationVoice;
        return Scaffold(
          appBar: AppBar(
            title: const Text('قصص الأنبياء'),
            actions: [
              if (st.supported)
                IconButton(
                  tooltip: 'تنزيل القصص للاستماع دون إنترنت',
                  icon: Icon(st.downloading ? Icons.downloading : Icons.download_for_offline_outlined),
                  onPressed: () => showStoryDownloads(context),
                ),
            ],
          ),
          body: list.isEmpty
              ? const Center(child: Text('سيتم إضافة القصص قريبًا'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length + 1,
                  itemBuilder: (c, i) {
                    if (i == 0) return st.downloading ? const _StoryProgress() : const SizedBox.shrink();
                    final p = list[i - 1];
                    final saved = st.isSaved(p.id, voice);
                    return Card3D(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Tile3D(
                          size: 44,
                          child: Text(Arabic.digits(p.order), style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        title: Text(p.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                        subtitle: Text(p.title, style: TextStyle(color: AppColors.gold)),
                        trailing: !st.supported || !app.narration.hasRecording(p.id, voice)
                            ? const Icon(Icons.chevron_left)
                            : saved
                                ? Tooltip(
                                    message: 'محفوظة على الهاتف',
                                    child: Icon(Icons.offline_pin, color: AppColors.emerald),
                                  )
                                : IconButton(
                                    tooltip: 'تنزيل هذه القصة',
                                    icon: const Icon(Icons.download_outlined),
                                    onPressed: st.downloading ? null : () => st.download([voice], ids: [p.id]),
                                  ),
                        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProphetPage(prophet: p))),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _StoryProgress extends StatelessWidget {
  const _StoryProgress();
  @override
  Widget build(BuildContext context) {
    final st = app.stories;
    final p = app.repo.prophets.where((x) => x.id == st.currentId).firstOrNull;
    final voices = st.jobGenders.map((g) => Narration.recordedNames[g] ?? '').join(' و');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: hero3D(radius: 18),
      child: Row(children: [
        const Icon(Icons.mic, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('جارٍ تنزيل القصص بصوت $voices', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            Text('${p != null ? 'قصة ${p.nameAr} • ' : ''}${Arabic.digits((st.progress * 100).round())}٪',
                style: TextStyle(color: AppColors.heroText, fontSize: 12.5)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: st.progress, color: AppColors.gold, backgroundColor: Colors.white24),
          ]),
        ),
        TextButton(onPressed: st.cancel, child: const Text('إيقاف', style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}

/// Choose the voice(s) and download every story for offline listening.
void showStoryDownloads(BuildContext context) {
  final st = app.stories;
  var choice = app.settings.narrationVoice; // 'male' | 'female' | 'both'
  showModalBottomSheet(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        Widget opt(String id, String label, int mb, int saved) => RadioListTile<String>(
              value: id,
              groupValue: choice,
              onChanged: (v) => set(() => choice = v!),
              title: Text(label),
              subtitle: saved > 0 ? Text('محفوظ ${Arabic.digits(saved)} من ${Arabic.digits(st.storyCount('male'))} قصة') : null,
              secondary: Text('${Arabic.digits(mb)} ميجابايت', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('تنزيل القصص للاستماع دون إنترنت', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text('٢٥ قصة مسجّلة. يُفضَّل التنزيل عبر Wi-Fi، ويستمر التنزيل إذا خرجت من التطبيق.', style: TextStyle(fontSize: 12.5)),
              ),
              opt('male', 'صوت رجل (نبيل)', st.sizeMB('male'), st.savedStories('male')),
              opt('female', 'صوت امرأة (عرين)', st.sizeMB('female'), st.savedStories('female')),
              opt('both', 'الصوتان معًا', st.sizeMB('male') + st.sizeMB('female'), 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('تنزيل كل القصص'),
                    onPressed: st.downloading
                        ? null
                        : () {
                            Navigator.pop(c);
                            st.download(choice == 'both' ? ['male', 'female'] : [choice]);
                          },
                  ),
                ),
              ),
              if (st.anySaved)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(c);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('حذف القصص المحفوظة'),
                          content: const Text('ستُحذف تسجيلات القصص من الهاتف، ويمكنك تنزيلها مرة أخرى في أي وقت.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (ok == true) await st.deleteAll();
                    },
                    child: const Text('حذف القصص المحفوظة', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
            ]),
          ),
        );
      },
    ),
  );
}

class ProphetPage extends StatelessWidget {
  final Prophet prophet;
  const ProphetPage({super.key, required this.prophet});

  static void _narrate(Prophet p) {
    app.recitation.stop();
    app.narration.onFinished = () {
      if (!app.settings.storyAutoplay) return;
      final list = app.repo.prophets;
      final i = list.indexWhere((x) => x.id == p.id);
      if (i >= 0 && i + 1 < list.length) app.narration.scheduleNext(list[i + 1].id);
    };
    if (app.narration.hasRecording(p.id, app.settings.narrationVoice)) {
      app.narration.playRecorded(p.id, app.settings.narrationVoice, title: p.nameAr);
      return;
    }
    app.narration.speak([
      '${p.nameAr}. ${p.title}. ${p.summary}',
      for (final s in p.sections) ...['${s.heading}.', ...s.body.split('\n\n')],
      if (p.lessons.isNotEmpty) 'دروس وعبر. ${p.lessons.join(' ')}',
    ], gender: app.settings.narrationVoice, voice: _voiceOf(), pitch: _pitchOf(), rate: _rateOf());
  }

  static bool get _female => app.settings.narrationVoice == 'female';
  static String _voiceOf() => _female ? app.settings.voiceFemale : app.settings.voiceMale;
  static double _pitchOf() => _female ? app.settings.pitchFemale : app.settings.pitchMale;
  static double _rateOf() => _female ? app.settings.rateFemale : app.settings.rateMale;

  @override
  Widget build(BuildContext context) {
    final p = prophet;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16.5, height: 1.9);
    // When the countdown ends, open the next story here and start it.
    app.narration.onAdvance = (id) {
      final next = app.repo.prophets.firstWhere((x) => x.id == id, orElse: () => p);
      if (context.mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ProphetPage(prophet: next)));
      }
      _narrate(next);
    };
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(p.nameAr)),
        bottomNavigationBar: ListenableBuilder(
          listenable: app.narration,
          builder: (context, _) {
            final id = app.narration.pendingNext;
            if (id == null) return const SizedBox.shrink();
            final next = app.repo.prophets.firstWhere((x) => x.id == id, orElse: () => p);
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.navy3, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(
                    width: 36, height: 36, alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 3)),
                    child: Text(Arabic.digits(app.narration.secondsLeft),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('القصة التالية: ${next.nameAr}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text('تبدأ بعد ${Arabic.digits(app.narration.secondsLeft)} ثوانٍ',
                          style: TextStyle(color: AppColors.heroText, fontSize: 12)),
                    ]),
                  ),
                  TextButton(
                    onPressed: app.narration.cancelNext,
                    child: Text('إلغاء', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            );
          },
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 32), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: hero3D(radius: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nameAr, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              Text(p.title, style: TextStyle(color: AppColors.goldLight, fontSize: 15)),
              const SizedBox(height: 8),
              Text(p.summary, style: TextStyle(color: AppColors.heroText, height: 1.7)),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: app.narration,
                builder: (context, _) => Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      if (app.narration.speaking) {
                        app.narration.stop();
                      } else {
                        _narrate(p);
                      }
                    },
                    icon: Icon(app.narration.speaking ? Icons.stop : Icons.headphones),
                    label: Text(app.narration.speaking ? 'إيقاف القراءة' : 'استمع إلى القصة'),
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white, selectedForegroundColor: AppColors.navy,
                      selectedBackgroundColor: AppColors.goldLight, side: const BorderSide(color: Colors.white54),
                    ),
                    segments: const [
                      ButtonSegment(value: 'male', icon: Icon(Icons.man), label: Text('رجل')),
                      ButtonSegment(value: 'female', icon: Icon(Icons.woman), label: Text('امرأة')),
                    ],
                    selected: {app.settings.narrationVoice},
                    onSelectionChanged: (v) async {
                      final wasSpeaking = app.narration.speaking;
                      await app.update((x) => x.narrationVoice = v.first, reschedule: false);
                      if (wasSpeaking) _narrate(p);
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: app.settings.storyAutoplay ? AppColors.goldLight : null,
                      foregroundColor: app.settings.storyAutoplay ? AppColors.navy : Colors.white,
                      side: BorderSide(color: app.settings.storyAutoplay ? AppColors.goldLight : Colors.white54),
                    ),
                    onPressed: () {
                      final on = !app.settings.storyAutoplay;
                      app.update((x) => x.storyAutoplay = on, reschedule: false);
                      if (!on) app.narration.cancelNext();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(on ? 'التشغيل التلقائي مفعّل: تبدأ القصة التالية بعد انتهاء الحالية' : 'تم إيقاف التشغيل التلقائي'),
                      ));
                    },
                    icon: const Icon(Icons.skip_next),
                    label: const Text('تلقائي'),
                  ),
                  if (app.narration.hasRecording(p.id, app.settings.narrationVoice))
                    Text('🎙 تسجيل بصوت ${Narration.recordedNames[app.settings.narrationVoice]}',
                        style: TextStyle(color: AppColors.goldLight, fontSize: 13))
                  else
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => VoiceTuningSheet(gender: app.settings.narrationVoice),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('ضبط الصوت'),
                  ),
                ]),
              ),
            ]),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([app.narration, app.recitation]),
            builder: (context, _) {
              final err = app.narration.error ?? app.recitation.error;
              return err == null
                  ? const SizedBox.shrink()
                  : Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: TextStyle(color: AppColors.gold)));
            },
          ),
          for (final s in p.sections) ...[
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 4, height: 22, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(child: Text(s.heading, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            for (final para in s.body.split('\n\n').where((x) => x.trim().isNotEmpty))
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(para.trim(), style: body, textAlign: TextAlign.justify)),
          ],
          if (p.ayat.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('من آيات القرآن الكريم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final a in p.ayat) _AyatCard(a),
          ],
          if (p.lessons.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('دروس وعبر', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final l in p.lessons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.star, size: 14, color: AppColors.gold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l, style: body)),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

class _AyatCard extends StatelessWidget {
  final AyahRef a;
  const _AyatCard(this.a);

  @override
  Widget build(BuildContext context) {
    if (a.surah < 1 || a.surah > 114) return const SizedBox.shrink();
    final s = app.repo.surahs[a.surah - 1];
    final from = a.from.clamp(1, s.verses.length);
    final to = a.to.clamp(from, s.verses.length);
    final style = quranStyle(context, 21);
    return Card3D(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openReader(context, a.surah, from),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text.rich(
              TextSpan(children: [
                for (var i = from; i <= to; i++) ...[
                  TextSpan(text: '${s.verses[i - 1]} '),
                  TextSpan(text: '${ayahNumber(i)} ', style: style.copyWith(color: AppColors.gold, fontSize: 19)),
                ],
              ]),
              style: style,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 6),
            Text('سورة ${s.name} (${Arabic.digits(from)}${to > from ? '–${Arabic.digits(to)}' : ''})',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
            if (a.note.isNotEmpty) Text(a.note, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () {
                  app.narration.stop();
                  app.recitation.onFinished = null;
                  app.recitation.play(app.repo, app.settings.reciterId, a.surah, from, to);
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('استماع للتلاوة'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


/// Lets the user pick the device voice and tune pitch/speed for the male or female narrator.
class VoiceTuningSheet extends StatefulWidget {
  final String gender;
  const VoiceTuningSheet({super.key, required this.gender});
  @override
  State<VoiceTuningSheet> createState() => _VoiceTuningSheetState();
}

class _VoiceTuningSheetState extends State<VoiceTuningSheet> {
  late String _gender = widget.gender;
  List<Map<String, String>> _voices = [];
  late String _voice;
  late double _pitch, _rate;

  @override
  void initState() {
    super.initState();
    _load();
    app.narration.arabicVoices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
  }

  void _load() {
    final s = app.settings;
    final f = _gender == 'female';
    _voice = f ? s.voiceFemale : s.voiceMale;
    _pitch = f ? s.pitchFemale : s.pitchMale;
    _rate = f ? s.rateFemale : s.rateMale;
  }

  Future<void> _save() => app.update((x) {
        x.narrationVoice = _gender;
        if (_gender == 'female') {
          x.voiceFemale = _voice; x.pitchFemale = _pitch; x.rateFemale = _rate;
        } else {
          x.voiceMale = _voice; x.pitchMale = _pitch; x.rateMale = _rate;
        }
      }, reschedule: false);

  String _label(Map<String, String> v) {
    final g = v['gender'] == 'male' ? ' • رجل' : v['gender'] == 'female' ? ' • امرأة' : '';
    return '${v['name']} (${v['locale']})$g';
  }

  @override
  Widget build(BuildContext context) {
    final names = _voices.map((v) => v['name']!).toSet();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ضبط صوت قراءة القصص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', icon: Icon(Icons.man), label: Text('صوت رجل')),
                ButtonSegment(value: 'female', icon: Icon(Icons.woman), label: Text('صوت امرأة')),
              ],
              selected: {_gender},
              onSelectionChanged: (v) => setState(() { _gender = v.first; _load(); }),
            ),
            const SizedBox(height: 14),
            const Text('الصوت من أصوات الجهاز'),
            DropdownButton<String>(
              isExpanded: true,
              value: names.contains(_voice) ? _voice : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('تلقائي')),
                for (final v in _voices) DropdownMenuItem(value: v['name'], child: Text(_label(v), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _voice = v ?? ''),
            ),
            if (_voices.length <= 1)
              Text('جهازك فيه صوت عربي واحد. للحصول على أصوات أكثر (منها أصوات رجال): الإعدادات ← تحويل النص إلى كلام ← محرك Google ← تثبيت بيانات الصوت ← العربية.',
                  style: TextStyle(fontSize: 12, color: AppColors.gold)),
            const SizedBox(height: 12),
            Row(children: [
              const Text('طبقة الصوت'),
              const Spacer(),
              Text(_pitch < 0.8 ? 'عميق (أجش)' : _pitch > 1.05 ? 'رفيع' : 'طبيعي', style: TextStyle(color: AppColors.gold)),
            ]),
            Row(children: [
              const Text('أعمق', style: TextStyle(fontSize: 12)),
              Expanded(child: Slider(min: 0.5, max: 1.6, divisions: 22, value: _pitch.clamp(0.5, 1.6), onChanged: (v) => setState(() => _pitch = v))),
              const Text('أرفع', style: TextStyle(fontSize: 12)),
            ]),
            const Text('سرعة القراءة'),
            Row(children: [
              const Text('أبطأ', style: TextStyle(fontSize: 12)),
              Expanded(child: Slider(min: 0.25, max: 0.7, divisions: 9, value: _rate.clamp(0.25, 0.7), onChanged: (v) => setState(() => _rate = v))),
              const Text('أسرع', style: TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => app.narration.preview(_gender, voice: _voice, pitch: _pitch, rate: _rate),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('تجربة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await _save();
                    await app.narration.stop();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('حفظ'),
                ),
              ),
            ]),
            TextButton(
              onPressed: () => setState(() {
                _voice = '';
                _pitch = _gender == 'female' ? 1.1 : 0.62;
                _rate = _gender == 'female' ? 0.47 : 0.42;
              }),
              child: const Text('استعادة الإعدادات الافتراضية'),
            ),
          ]),
        ),
      ),
    );
  }
}
