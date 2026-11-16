<#
  Builds Mawaqeety and creates the installer on Windows.
  Requirements: .NET 10 SDK.  Optional: Inno Setup 6 (for the classic wizard installer).
  Usage:  ./installer/build.ps1 -Version 1.0.1
#>
param(
  [string]$Version = "1.0.0",
  [switch]$SkipTests,
  [switch]$Inno
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not $SkipTests) {
  dotnet test --project tests/Mawaqeety.Tests/Mawaqeety.Tests.csproj -c Release
  if ($LASTEXITCODE -ne 0) { throw "Tests failed" }
}

Remove-Item -Recurse -Force publish/win-x64 -ErrorAction SilentlyContinue
dotnet publish src/Mawaqeety.App/Mawaqeety.App.csproj -c Release -r win-x64 --self-contained true `
  -p:Version=$Version -o publish/win-x64
if ($LASTEXITCODE -ne 0) { throw "Publish failed" }

# Velopack: Setup.exe + auto-update packages (Releases/)
dotnet tool update -g vpk | Out-Null
vpk pack --packId Mawaqeety --packVersion $Version --packDir publish/win-x64 --mainExe Mawaqeety.exe `
  --packTitle "Mawaqeety - مواقيتي" --packAuthors "Mawaqeety" --icon src/Mawaqeety.App/Assets/mawaqeety.ico `
  --splashImage installer/splash.png --releaseNotes installer/ReleaseNotes.md --shortcuts "Desktop,StartMenuRoot" `
  --outputDir Releases
# To code-sign (recommended for distribution):  add  --signParams "/a /fd sha256 /tr http://timestamp.digicert.com /td sha256"

if ($Inno) {
  $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  & $iscc "/DAppVersion=$Version" installer/Mawaqeety.iss
}
Write-Host "Done. Installer: Releases/Mawaqeety-win-Setup.exe"
