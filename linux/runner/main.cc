#include "my_application.h"

int main(int argc, char** argv) {
  // El indicador de la bandeja no lleva título propio, así que el panel cae al
  // nombre de GLib y muestra "Dev.jose.FileFly". Va aquí y no en activate:
  // GApplication lo fija durante su startup y la segunda llamada se ignora.
  g_set_application_name("FileFly");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
