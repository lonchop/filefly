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

[CustomMessages]
spanish.AutoStartTask=Arrancar FileFly con la sesión, en la bandeja
english.AutoStartTask=Start FileFly with Windows, in the tray
spanish.AutoStartGroup=Arranque
english.AutoStartGroup=Startup

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FileFly"; Filename: "{app}\filefly.exe"
Name: "{autodesktop}\FileFly"; Filename: "{app}\filefly.exe"; Tasks: desktopicon
; --hidden deja la ventana sin mostrarse: en el arranque de sesión FileFly solo
; tiene que quedar en la bandeja para que el celular lo encuentre.
Name: "{userstartup}\FileFly"; Filename: "{app}\filefly.exe"; Parameters: "--hidden"; Tasks: autostart

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
; Marcada por defecto, igual que tool/install_linux.sh, que escribe la entrada
; de autostart sin preguntar.
Name: "autostart"; Description: "{cm:AutoStartTask}"; GroupDescription: "{cm:AutoStartGroup}"

[Run]
Filename: "{app}\filefly.exe"; Description: "{cm:LaunchProgram,FileFly}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The token and the shared folder pointer live in %APPDATA%\filefly and are
; deliberately left behind, so reinstalling does not invalidate a paired phone.
Type: dirifempty; Name: "{app}"
