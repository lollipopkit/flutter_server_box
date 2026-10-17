#define AppName GetEnv("APP_NAME")
#define AppVersion GetEnv("APP_VERSION")
#define MsiEnPath GetEnv("MSI_EN_PATH")
#define MsiZhPath GetEnv("MSI_ZH_PATH")

[Setup]
AppId={{9E2CE26A-5B63-4CDE-97D4-E4E8952EA137}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\Server Box
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\..
OutputBaseFilename={#AppName}_v{#AppVersion}_windows_amd64_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=yes
LanguageDetectionMethod=uilanguage
UsePreviousLanguage=no
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "{#MsiEnPath}"; DestName: "ServerBox_en-US.msi"; Flags: dontcopy noencryption
Source: "{#MsiZhPath}"; DestName: "ServerBox_zh-CN.msi"; Flags: dontcopy noencryption

[Run]
Filename: "{sys}\msiexec.exe"; Parameters: "/i ""{tmp}\ServerBox_en-US.msi"""; Flags: waituntilterminated; Languages: english
Filename: "{sys}\msiexec.exe"; Parameters: "/i ""{tmp}\ServerBox_zh-CN.msi"""; Flags: waituntilterminated; Languages: chinesesimplified

[Code]
procedure InitializeWizard;
begin
  if ActiveLanguage = 'chinesesimplified' then
    ExtractTemporaryFile('ServerBox_zh-CN.msi')
  else
    ExtractTemporaryFile('ServerBox_en-US.msi');
end;