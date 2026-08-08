; Inno Setup script for FileFly.
;
; Flutter cannot produce a single self-contained executable: the engine lives in
; flutter_windows.dll and the assets in data\, both loaded from disk next to the
; launcher. This installer is the way to ship one downloadable file anyway.
;
; It installs under the user profile, like tool/install_linux.sh does on Linux,
; so it never asks for administrator rights.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{B9F56670-6F5F-4A31-8FD4-B100E99BA47B}
AppName=FileFly
AppVersion={#AppVersion}
AppPublisher=Orangel Jose Gonzalez
DefaultDirName={autopf}\FileFly
DefaultGroupName=FileFly
UninstallDisplayIcon={app}\filefly.exe
OutputDir=..\..\build\installer
OutputBaseFilename=FileFly-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installing per user keeps this out of Program Files and away from UAC.
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FileFly"; Filename: "{app}\filefly.exe"
Name: "{autodesktop}\FileFly"; Filename: "{app}\filefly.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\filefly.exe"; Description: "{cm:LaunchProgram,FileFly}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The token and the shared folder pointer live in %APPDATA%\filefly and are
; deliberately left behind, so reinstalling does not invalidate a paired phone.
Type: dirifempty; Name: "{app}"
