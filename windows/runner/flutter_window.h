#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// Mensaje que un segundo arranque difunde para que la instancia que ya corre
// saque su ventana. RegisterWindowMessage traduce este nombre al mismo id en
// los dos procesos y garantiza que no choque con ningún WM_ del sistema.
inline constexpr wchar_t kShowExistingWindowMessage[] =
    L"FileFly.ShowExistingWindow";

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // Con |starts_hidden| la ventana no se muestra en el primer frame y FileFly
  // queda solo en la bandeja.
  FlutterWindow(const flutter::DartProject& project, bool starts_hidden);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // Si el arranque pidió quedarse solo en la bandeja.
  bool starts_hidden_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
