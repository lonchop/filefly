import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Mantiene FileFly vivo cuando se cierra la ventana.
///
/// El servidor vive en el árbol de widgets, así que esconder la ventana en vez
/// de destruirla deja el puerto escuchando y el celular no se entera. La
/// bandeja es la única vía de vuelta: si no se pudo registrar, la X vuelve a
/// cerrar de verdad antes que dejar un proceso invisible sin forma de salir.
class TrayLifecycle with WindowListener, TrayListener {
  static const _showKey = 'show';
  static const _quitKey = 'quit';

  Future<void> start() async {
    try {
      await _setUpTray();
    } on Exception catch (err) {
      // Sin bandeja no hay vuelta atrás, así que la X vuelve a cerrar de
      // verdad. Se avisa por stderr: un catch mudo aquí esconde justo el
      // fallo que deja la app sin forma de volver.
      stderr.writeln('FileFly: no se pudo registrar la bandeja: $err');
      return;
    }
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() => unawaited(windowManager.hide());

  @override
  void onTrayIconMouseDown() => unawaited(_restore());

  // En Linux el indicador solo responde con el menú, así que el clic derecho
  // se atiende igual en las dos plataformas.
  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == _quitKey) {
      unawaited(_quit());
      return;
    }
    unawaited(_restore());
  }

  Future<void> _setUpTray() async {
    // El .ico es obligatorio en Windows; en Linux el PNG de 32 es el que mejor
    // aguanta el escalado del panel.
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/icons/filefly.ico' : 'assets/icons/filefly-32.png',
    );
    // El plugin de Linux solo implementa destroy, setIcon, setTitle y
    // setContextMenu: pedirle el tooltip lanza MissingPluginException y deja
    // la bandeja a medio montar.
    if (Platform.isWindows) {
      await trayManager.setToolTip('FileFly');
    }
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: _showKey, label: 'Abrir FileFly'),
      MenuItem.separator(),
      MenuItem(key: _quitKey, label: 'Salir'),
    ]));
  }

  Future<void> _restore() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
