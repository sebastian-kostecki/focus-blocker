; Inno Setup script for the FocusBlocker installer (the app only; the browser extension
; is still loaded by hand). It unpacks the scripts to a temp folder and runs install.ps1,
; so all installation logic stays in one place.
; Build:  ISCC.exe /DAppVersion=1.3.0 installer\FocusBlocker.iss   (output: dist\)

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{B7C1F4E2-5A0D-4C36-9E1B-4F6A2D7C8E90}
AppName=FocusBlocker
AppVersion={#AppVersion}
AppPublisher=Sebastian Kostecki
AppPublisherURL=https://github.com/sebastian-kostecki/focus-blocker
; Only the uninstaller lives here; the program itself is installed by install.ps1
DefaultDirName={commonpf}\FocusBlocker
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\dist
OutputBaseFilename=FocusBlocker-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=FocusBlocker

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"

[CustomMessages]
english.BlockActive=A block is active right now. FocusBlocker can't be installed, updated or removed until it ends.
english.InstallFailed=The installation script reported an error. Run install.ps1 from the release ZIP as administrator to see the details.
english.LaunchApp=Open the FocusBlocker menu
polish.BlockActive=Trwa blokada. FocusBlockera nie można instalować, aktualizować ani usuwać, dopóki się nie skończy.
polish.InstallFailed=Skrypt instalacyjny zgłosił błąd. Uruchom install.ps1 z ZIP-a jako administrator, żeby zobaczyć szczegóły.
polish.LaunchApp=Otwórz menu FocusBlockera

[Files]
Source: "..\*.ps1"; DestDir: "{tmp}\FocusBlocker"; Flags: ignoreversion deleteafterinstall
Source: "..\blocklist.txt"; DestDir: "{tmp}\FocusBlocker"; Flags: ignoreversion deleteafterinstall
Source: "..\config.json"; DestDir: "{tmp}\FocusBlocker"; Flags: ignoreversion deleteafterinstall
Source: "..\README.md"; DestDir: "{tmp}\FocusBlocker"; Flags: ignoreversion deleteafterinstall
Source: "..\extension\*"; DestDir: "{tmp}\FocusBlocker\extension"; Flags: ignoreversion recursesubdirs deleteafterinstall

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{commonappdata}\FocusBlocker\focus.ps1"""; Description: "{cm:LaunchApp}"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{commonappdata}\FocusBlocker\uninstall.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "FocusBlockerUninstall"

[Code]
// A running block must never be bypassed by reinstalling or uninstalling.
function BlockActive(): Boolean;
var
  Dir, Lib, Args: String;
  Code: Integer;
begin
  Result := False;
  Dir := ExpandConstant('{commonappdata}\FocusBlocker');
  Lib := Dir + '\lib.ps1';
  if not FileExists(Lib) then Exit;
  Args := '-NoProfile -ExecutionPolicy Bypass -Command "$FB_Dir = ''' + Dir + '''; . ''' + Lib + '''; if ((Get-FBStatus).Active) { exit 2 }"';
  if Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Args, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := (Code = 2);
end;

function InitializeSetup(): Boolean;
begin
  Result := not BlockActive();
  if not Result then
    MsgBox(CustomMessage('BlockActive'), mbError, MB_OK);
end;

function InitializeUninstall(): Boolean;
begin
  Result := not BlockActive();
  if not Result then
    MsgBox(CustomMessage('BlockActive'), mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'FocusBlocker';
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
         ExpandConstant('-NoProfile -ExecutionPolicy Bypass -File "{tmp}\FocusBlocker\install.ps1"'),
         '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
      MsgBox(CustomMessage('InstallFailed'), mbError, MB_OK);
  end;
end;
