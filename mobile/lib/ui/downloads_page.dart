import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../main.dart';
import '../services/quran_downloads.dart';
import 'theme.dart';

/// Download recitations to listen without internet.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _sizes = <String, int>{};

  @override
  void initState() {
    super.initState();
    _refreshSizes();
  }

  Future<void> _refreshSizes() async {
    for (final r in app.repo.reciters) {
      final n = await app.downloads.sizeOnDisk(r.id);
      if (n > 0) _sizes[r.id] = n;
      else _sizes.remove(r.id);
    }
    if (mounted) setState(() {});
  }

  static String _mb(int bytes) => bytes >= 1e9
      ? '${Arabic.digits((bytes / 1e9).toStringAsFixed(1))} جيجابايت'
      : '${Arabic.digits((bytes / 1e6).round())} ميجابايت';

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف التلاوات المحفوظة'),
        content: Text('سيُحذف ما نزّلته بصوت $name من الهاتف. يمكنك تنزيله مرة أخرى في أي وقت.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await app.downloads.delete(id);
      await _refreshSizes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاستماع دون إنترنت')),
      body: ListenableBuilder(
        listenable: app.downloads,
        builder: (context, _) {
          final current = app.repo.reciter(app.settings.reciterId);
          final others = app.repo.reciters.where((r) => r.id != current.id && (app.downloads.readyCount(r.id) > 0 ||
              app.downloads.job(r.id) != null || (_sizes[r.id] ?? 0) > 0));
          if (!app.downloads.supported) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('التنزيل متاح في تطبيق أندرويد وآيفون.', textAlign: TextAlign.center),
            );
          }
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('نزّل المصحف كاملًا أو سورًا محددة لتستمع إليها دون اتصال بالإنترنت. '
                  'يُفضَّل التنزيل عبر Wi-Fi مع إبقاء التطبيق مفتوحًا حتى ينتهي.', style: TextStyle(fontSize: 13)),
            ),
            _ReciterCard(id: current.id, name: current.name, isCurrent: true, size: _sizes[current.id],
                onDelete: () => _confirmDelete(current.id, current.name), onChanged: _refreshSizes),
            if (others.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('تلاوات أخرى محفوظة', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            for (final r in others)
              _ReciterCard(id: r.id, name: r.name, isCurrent: false, size: _sizes[r.id],
                  onDelete: () => _confirmDelete(r.id, r.name), onChanged: _refreshSizes),
          ]);
        },
      ),
    );
  }
}

class _ReciterCard extends StatelessWidget {
  final String id, name;
  final bool isCurrent;
  final int? size;
  final VoidCallback onDelete;
  final Future<void> Function() onChanged;
  const _ReciterCard({required this.id, required this.name, required this.isCurrent, required this.size,
      required this.onDelete, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final d = app.downloads;
    final job = d.job(id);
    final ready = d.readyCount(id);
    final err = d.lastError[id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(ready == 114 ? Icons.offline_pin : Icons.record_voice_over_outlined,
                color: ready == 114 ? AppColors.emerald : AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            if (isCurrent) Text('القارئ الحالي', style: TextStyle(fontSize: 12, color: AppColors.gold)),
          ]),
          const SizedBox(height: 8),
          Text(
            ready == 114
                ? 'المصحف كامل محفوظ على الهاتف'
                : 'المحفوظ: ${Arabic.digits(ready)} من ١١٤ سورة',
            style: const TextStyle(fontSize: 13),
          ),
          if (size != null) Text('المساحة المستخدمة: ${_DownloadsPageState._mb(size!)}', style: const TextStyle(fontSize: 13)),
          if (job != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: job.progress, minHeight: 8, backgroundColor: AppColors.goldSoft, color: AppColors.gold),
            ),
            const SizedBox(height: 4),
            Text(job.cancelled
                ? 'جارٍ الإيقاف…'
                : 'جارٍ تنزيل سورة ${app.repo.surahs[(job.currentSurah.clamp(1, 114)) - 1].name} • ${Arabic.digits((job.progress * 100).round())}٪',
                style: const TextStyle(fontSize: 12)),
          ],
          if (err != null && job == null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
          const SizedBox(height: 12),
          Row(children: [
            if (job != null)
              Expanded(child: OutlinedButton.icon(onPressed: () => d.cancel(id), icon: const Icon(Icons.pause), label: const Text('إيقاف')))
            else if (ready < 114)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await d.download(app.repo, id);
                    await onChanged();
                  },
                  icon: const Icon(Icons.download),
                  label: Text(ready == 0 ? 'تنزيل المصحف كاملًا (≈ ${QuranDownloads.estimateFullSize(id)})' : 'إكمال التنزيل',
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            if ((size ?? 0) > 0 || ready > 0) ...[
              const SizedBox(width: 8),
              IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
            ],
          ]),
        ]),
      ),
    );
  }
}
