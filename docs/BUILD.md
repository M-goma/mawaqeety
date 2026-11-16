# البناء والتوزيع – Build & Release

## المتطلبات
- .NET 10 SDK فقط (لا حاجة إلى Visual Studio). جهاز المستخدم لا يحتاج أي شيء، فالنسخة self-contained.
- Velopack CLI:
```bash
dotnet tool install -g vpk
```

## الأوامر
```bash
dotnet build Mawaqeety.slnx -c Release
```
```bash
dotnet test --project tests/Mawaqeety.Tests/Mawaqeety.Tests.csproj
```
```powershell
./installer/build.ps1 -Version 1.0.0
```
الناتج في `Releases/`:
- `Mawaqeety-win-Setup.exe` — ملف التثبيت للمستخدم.
- `Mawaqeety-win-Portable.zip` — نسخة محمولة.
- `*.nupkg` و`releases.win.json` — ملفات التحديث التلقائي.

مثبّت كلاسيكي بخيارات (Inno Setup 6): `./installer/build.ps1 -Version 1.0.0 -Inno`.

ملاحظة: MSI غير مُنتج حاليًا. إذا احتجته لنشر مؤسسي (Intune/GPO)، أضِف `--msi` إلى `vpk pack` على Windows (يتطلب WiX).

## التحديثات التلقائية
1. ارفع محتويات `Releases/` إلى مكان ثابت، مثل GitHub Releases أو أي استضافة ملفات.
2. عدّل `UpdateService.FeedUrl` في `src/Mawaqeety.App/Services/UpdateService.cs`.
3. لكل إصدار جديد: ارفع رقم الإصدار، ثم شغّل build، ثم ارفع الملفات. زر "البحث عن تحديثات" يطبّق التحديث ويعيد التشغيل.

## التوقيع الرقمي (مهم للتوزيع)
بدون توقيع سيظهر تحذير SmartScreen. بعد الحصول على شهادة Code Signing:
```powershell
vpk pack ... --signParams "/a /fd sha256 /tr http://timestamp.digicert.com /td sha256"
```

## إعادة توليد الأصول
```bash
python3 tools/build_cities.py
```
```bash
python3 tools/make_assets.py
```
```bash
pip install astral && python3 tools/gen_reference.py
```
