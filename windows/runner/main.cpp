#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // El acceso directo de arranque con la sesión pasa --hidden para que FileFly
  // quede solo en la bandeja.
  const bool starts_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--hidden") != command_line_arguments.end();

  // Solo un FileFly puede quedarse con el puerto, así que un segundo arranque
  // le devuelve la ventana al que ya corre en vez de abrir uno que fallaría al
  // levantar el servidor. Con la bandeja esto dejó de ser raro: la app queda
  // viva e invisible y el acceso directo sigue ahí para que la vuelvan a
  // pulsar. El ámbito es Local\ porque el caso real es el mismo usuario
  // lanzando dos veces; a la sesión de otro usuario no se le podría mostrar la
  // ventana de todos modos. El mutex se deja abierto a propósito: lo libera el
  // sistema cuando termina el proceso.
  ::CreateMutexW(nullptr, TRUE, L"Local\\FileFly-SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Un arranque de sesión duplicado no tiene que sacar ninguna ventana.
    if (!starts_hidden) {
      // La instancia que ya corre no puede tomar el foco por su cuenta: se lo
      // cede esta, que sí lo tiene por venir de un gesto del usuario.
      ::AllowSetForegroundWindow(ASFW_ANY);
      ::PostMessage(HWND_BROADCAST,
                    ::RegisterWindowMessageW(kShowExistingWindowMessage), 0, 0);
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, starts_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"filefly", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
