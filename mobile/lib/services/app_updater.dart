import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStatus { upToDate, available, started, failed }

class UpdateResult {
  final UpdateStatus status;
  final String message;
  const UpdateResult(this.status, this.message);
}

/// "Check for updates" for every way the app can be installed:
/// - Google Play install  → Google Play in-app update (required by Play policy).
/// - APK from GitHub      → compares with the latest CI build and downloads the new APK.
/// - Web / iPhone browser → reloads the page.
class AppUpdater {
  static const apkUrl = 'https://github.com/M-goma/mawaqeety/releases/download/mobile-latest/Mawaqeety.apk';
  static const versionUrl = 'https://m-goma.github.io/mawaqeety/version.json';

  PackageInfo? _info;

  Future<PackageInfo> info() async => _info ??= await PackageInfo.fromPlatform();

  Future<String> versionLabel() async {
    final i = await info();
    return '${i.version} (${i.buildNumber})';
  }

  bool _fromPlay(PackageInfo i) => i.installerStore == 'com.android.vending';

  /// Latest published build number (CI run number), or null when offline.
  Future<int?> _latestBuild() async {
    try {
      final r = await http
          .get(Uri.parse('$versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return int.tryParse('${jsonDecode(r.body)['build_number']}');
    } catch (_) {
      return null;
    }
  }

  /// Checks only; [apply] = true also starts the update.
  Future<UpdateResult> check({bool apply = true}) async {
    try {
      final i = await info();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && _fromPlay(i)) {
        final u = await InAppUpdate.checkForUpdate();
        if (u.updateAvailability != UpdateAvailability.updateAvailable) {
          return const UpdateResult(UpdateStatus.upToDate, 'أنت تستخدم أحدث إصدار.');
        }
        if (!apply) return const UpdateResult(UpdateStatus.available, 'يتوفر إصدار جديد على Google Play.');
        await InAppUpdate.performImmediateUpdate();
        return const UpdateResult(UpdateStatus.started, 'جارٍ التحديث من Google Play...');
      }

      final latest = await _latestBuild();
      final current = int.tryParse(i.buildNumber) ?? 0;
      if (latest == null) return const UpdateResult(UpdateStatus.failed, 'تعذّر التحقق من التحديثات. تأكد من الاتصال بالإنترنت.');
      if (latest <= current) return const UpdateResult(UpdateStatus.upToDate, 'أنت تستخدم أحدث إصدار.');
      if (!apply) return const UpdateResult(UpdateStatus.available, 'يتوفر إصدار جديد من سبيل.');

      if (kIsWeb) {
        await launchUrl(Uri.base, webOnlyWindowName: '_self');
        return const UpdateResult(UpdateStatus.started, 'جارٍ تحميل أحدث نسخة...');
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
        return const UpdateResult(UpdateStatus.started,
            'جارٍ تنزيل التحديث. افتح الملف بعد اكتمال التنزيل واضغط «تثبيت».');
      }
      return const UpdateResult(UpdateStatus.available, 'يتوفر إصدار جديد.');
    } catch (e) {
      debugPrint('update check failed: $e');
      return const UpdateResult(UpdateStatus.failed, 'تعذّر التحقق من التحديثات.');
    }
  }
}
