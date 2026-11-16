#!/usr/bin/env bash
# Cross-builds the Windows installer from Linux/macOS (Velopack supports cross-compiling, unsigned).
# Requirements: .NET 10 SDK, `dotnet tool install -g vpk`.
set -euo pipefail
VERSION="${1:-1.0.0}"
cd "$(dirname "$0")/.."
dotnet test --project tests/Mawaqeety.Tests/Mawaqeety.Tests.csproj -c Release
rm -rf publish/win-x64
dotnet publish src/Mawaqeety.App/Mawaqeety.App.csproj -c Release -r win-x64 --self-contained true -p:Version="$VERSION" -o publish/win-x64
vpk "[win]" pack --packId Mawaqeety --packVersion "$VERSION" --packDir publish/win-x64 --mainExe Mawaqeety.exe \
  --packTitle "Mawaqeety - مواقيتي" --packAuthors "Mawaqeety" --icon src/Mawaqeety.App/Assets/mawaqeety.ico \
  --splashImage installer/splash.png --releaseNotes installer/ReleaseNotes.md --shortcuts "Desktop,StartMenuRoot" \
  --outputDir Releases
echo "Installer: Releases/Mawaqeety-win-Setup.exe"
