# سبيل – رفيق المسلم

Flutter app in `mobile/`, WPF desktop in `src/` (Arabic, RTL).

## Rules

- **Every new content section must be registered with «سبيل»** so the assistant can answer from it:
  - mobile: one `LibrarySource` in `SabeelLibrary.sources` (`mobile/lib/data/sabeel_library.dart`);
  - desktop: one `LibrarySource` in `SabeelLibrary.Sources` (`src/Mawaqeety.Core/Content/SabeelLibrary.cs`) and one case in `SabeelViewModel.OpenEntry`.
  `mobile/test/sabeel_library_test.dart` and `tests/Mawaqeety.Tests/SabeelLibraryTests.cs` fail when a data asset/resource is not registered (or listed as non-content).
- **Religious content must be sourced**: quote it from a named source (Quran, the two Sahihs, a published fatwa or book with its reference/URL). Never write or generate religious text; «سبيل» only quotes app content.
- **New features go in «المزيد»** (`mobile/lib/ui/more_page.dart`), never straight onto the Home tab. The Home tab shows only what each user picks in Settings › «تخصيص الصفحة الرئيسية» (`mobile/lib/ui/home_layout.dart`): add a new page there as an optional shortcut (and a new Home card, if any, as a section that is off by default).
- Store "what's new" texts (`mobile/distribution/whatsnew/`) must stay under 500 characters.
