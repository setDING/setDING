; Windows setup for setDING (ADR-0035), built with Inno Setup 6 by the release
; workflow (.github/workflows/release.yml):
;
;   iscc /DAppVersion=0.9.0 /DSourceDir=<release folder> /DOutputDir=<dir>
;        /DOutputBase=setding-0.9.0-windows-x64-setup setding.iss
;
; Installs per user (no administrator rights) into
; %LOCALAPPDATA%\Programs\setDING. Running a newer setup updates the
; installation in place; the app runs it silently itself
; (lib/update/app_update.dart, installerArguments) and is started again by the
; [Run] entry. The data lives in %APPDATA%, outside the installation, and
; stays on updates and on uninstall.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\windows\installer"
#endif
#ifndef OutputBase
  #define OutputBase "setding-" + AppVersion + "-windows-x64-setup"
#endif

[Setup]
; Never change the AppId: it identifies the installation that updates replace.
AppId={{789C6255-6857-4E90-8124-611AA042D115}
AppName=setDING
AppVersion={#AppVersion}
AppVerName=setDING {#AppVersion}
AppPublisher=setDING
AppPublisherURL=https://setding.app
AppSupportURL=https://github.com/tafli/setDING/issues
AppUpdatesURL=https://github.com/tafli/setDING/releases
DefaultDirName={autopf}\setDING
DefaultGroupName=setDING
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\setding.exe
UninstallDisplayName=setDING
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no
ShowLanguageDialog=auto

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Assets of the previous version (Flutter's data folder) are replaced as a whole.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; setding:// links open the app: invitations (ADR-0005) and sets and songs
; (ADR-0065). Per user, like the installation (PrivilegesRequired=lowest);
; removed with the app.
Root: HKA; Subkey: "Software\Classes\setding"; ValueType: string; ValueName: ""; ValueData: "URL:setDING"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\setding"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\setding\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\setding.exe,0"
Root: HKA; Subkey: "Software\Classes\setding\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\setding.exe"" ""%1"""

[Icons]
Name: "{autoprograms}\setDING"; Filename: "{app}\setding.exe"
Name: "{autodesktop}\setDING"; Filename: "{app}\setding.exe"; Tasks: desktopicon

[Run]
; No skipifsilent: after a silent update from the app, the new version starts.
Filename: "{app}\setding.exe"; Description: "{cm:LaunchProgram,setDING}"; Flags: nowait postinstall
