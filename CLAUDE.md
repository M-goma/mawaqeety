# سبيل – رفيق المسلم

Flutter app in `mobile/`, WPF desktop in `src/` (Arabic, RTL).

## Rules

- **Every new content section must be registered with «سبيل»** so the assistant can answer from it:
  - mobile: one `LibrarySource` in `SabeelLibrary.sources` (`mobile/lib/data/sabeel_library.dart`);
  - desktop: one `LibrarySource` in `SabeelLibrary.Sources` (`src/Mawaqeety.Core/Content/SabeelLibrary.cs`) and one case in `SabeelViewModel.OpenEntry`.
  `mobile/test/sabeel_library_test.dart` and `tests/Mawaqeety.Tests/SabeelLibraryTests.cs` fail when a data asset/resource is not registered (or listed as non-content).
- **Religious content must be sourced**: quote it from a named source (Quran, the two Sahihs, a published fatwa or book with its reference/URL). Never write or generate religious text; «سبيل» only quotes app content.
- Store "what's new" texts (`mobile/distribution/whatsnew/`) must stay under 500 characters.
