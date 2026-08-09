import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filefly/app/theme.dart';
import 'package:filefly/ui/widgets/connect_panel.dart';
import 'package:filefly/ui/widgets/send_panel.dart';

/// El layout ancho pone los dos paneles de arriba en una fila y los cierra
/// sobre un único canto inferior.
///
/// Esto refleja `_TopPanels`: un `IntrinsicHeight` que aporta la altura acotada
/// que `stretch` necesita, dentro de un scroll que si no dejaría la fila sin
/// acotar. Lo que se prueba es esa pareja: si se quita cualquiera de las dos
/// mitades, la tarjeta de envío vuelve en silencio a ajustarse a su contenido,
/// que es justo el hueco que este layout existe para cerrar.
void main() {
  testWidgets('the send card fills the height of the taller connect card', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SendPanel(onFilesChosen: (_) async {}, fillHeight: true),
                  ),
                  const SizedBox(width: Space.xl),
                  const SizedBox(
                    width: 420,
                    child: ConnectPanel(shareUrls: ['http://192.168.0.38:8765/?token=abc']),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final send = tester.getSize(find.byType(SendPanel)).height;
    final connect = tester.getSize(find.byType(ConnectPanel)).height;

    expect(tester.takeException(), isNull);
    expect(send, connect);

    // La tarjeta de conectar es la más alta de las dos, así que una
    // coincidencia de este tamaño solo ocurre si la tarjeta de envío creció de
    // verdad.
    expect(send, greaterThan(400));
  });

  testWidgets('the narrow layout keeps the drop zone usable', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SendPanel(onFilesChosen: (_) async {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SendPanel)).height, greaterThan(240));
  });
}
