; Alternative classic installer (wizard with checkboxes) using Inno Setup 6 — build on Windows:
;   ISCC.exe /DAppVersion=1.0.0 installer\Mawaqeety.iss
; Expects the self-contained publish output in publish\win-x64 (see build.ps1).
; Note: auto-update is provided by the Velopack Setup.exe; this installer updates by running a newer setup.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6E2B9C1A-4F7D-4E21-9B5A-8C3D2E1F0A77}
AppName=Mawaqeety - مواقيتي
AppVersion={#AppVersion}
AppPublisher=Mawaqeety
AppVerName=Mawaqeety {#AppVersion}
DefaultDirName={localappdata}\Programs\Mawaqeety
DefaultGroupName=Mawaqeety
PrivilegesRequired=lowest
OutputDir=..\Releases
OutputBaseFilename=Mawaqeety-Setup-{#AppVersion}-inno
SetupIconFile=..\src\Mawaqeety.App\Assets\mawaqeety.ico
UninstallDisplayIcon={app}\Mawaqeety.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "تشغيل مواقيتي تلقائيًا مع Windows / Start with Windows"; GroupDescription: "Windows:"

[Files]
Source: "..\publish\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{group}\Mawaqeety - مواقيتي"; Filename: "{app}\Mawaqeety.exe"
Name: "{group}\{cm:UninstallProgram,Mawaqeety}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Mawaqeety - مواقيتي"; Filename: "{app}\Mawaqeety.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Mawaqeety"; \
  ValueData: """{app}\Mawaqeety.exe"" --background"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\Mawaqeety.exe"; Description: "{cm:LaunchProgram,Mawaqeety}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM Mawaqeety.exe /F"; Flags: runhidden; RunOnceId: "KillApp"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Mawaqeety\logs"
