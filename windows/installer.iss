; Inno Setup 6 script, compiled by `fl_build -p windows`, which passes
; AppName, AppVersion, SourceDir, OutputDir and OutputBaseFilename.
;
; Per user, into %LOCALAPPDATA%\Programs, so no administrator is needed. The
; app keeps its data in the user's app-data directory, not here, so an upgrade
; or an uninstall leaves it alone.

#ifndef AppName
  #error AppName is not defined
#endif
#ifndef AppVersion
  #error AppVersion is not defined
#endif
#ifndef SourceDir
  #error SourceDir is not defined
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename AppName + "_setup"
#endif
#define AppExe AppName + ".exe"

[Setup]
; Fixed for good: a new version installs over the one with the same id.
AppId={{9BB7C81E-6D14-4336-923D-A058909B6B71}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=lollipopkit
AppPublisherURL=https://github.com/lollipopkit/flutter_server_box
AppSupportURL=https://github.com/lollipopkit/flutter_server_box/issues
AppUpdatesURL=https://github.com/lollipopkit/flutter_server_box/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; A running instance holds its files open: close it rather than ask for a
; reboot.
CloseApplications=force
RestartApplications=no
; Only when Windows' own language is not listed below.
ShowLanguageDialog=auto

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "ja"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "ko"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "pt"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "uk"; MessagesFile: "compiler:Languages\Ukrainian.isl"
; Not shipped with Inno Setup 6.7: its unofficial translations, from the
; is-6_7_1 tag of jrsoftware/issrc.
Name: "zh"; MessagesFile: "installer\ChineseSimplified.isl"
Name: "zh_tw"; MessagesFile: "installer\ChineseTraditional.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Replaced whole, so an asset the new version no longer has does not linger.
; Only what Flutter puts there: on a first install {app} is any directory the
; user picked, and its `data` may not be ours.
Type: filesandordirs; Name: "{app}\data\flutter_assets"
Type: files; Name: "{app}\data\app.so"
Type: files; Name: "{app}\data\icudtl.dat"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
