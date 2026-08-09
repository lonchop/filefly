import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filefly/app/theme.dart';
import 'package:filefly/server/file_server.dart';
import 'package:filefly/ui/widgets/files_browser.dart';

final _files = [
  SharedFile(
    name: 'informe.pdf',
    path: '/tmp/filefly/informe.pdf',
    size: 2 * 1024 * 1024,
    modified: DateTime(2026, 8, 9, 14, 20),
  ),
  SharedFile(
    name: 'notas.txt',
    path: '/tmp/filefly/notas.txt',
    size: 1200,
    modified: DateTime(2026, 8, 8, 9, 5),
  ),
];

/// Monta el navegador de archivos tal como lo monta la ventana: dentro de un
/// `Expanded`, con una altura de ventana conocida.
Future<void> _pump(WidgetTester tester, {bool narrow = false, double height = 800}) async {
  tester.view.physicalSize = Size(narrow ? 600 : 1280, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: FilesBrowser(
                narrow: narrow,
                files: _files,
                folderPath: '/home/jose/FileFly',
                onSend: () {},
                onRefresh: () {},
                onOpenFolder: () {},
                onChangeFolder: () {},
                onOpenFile: (_) {},
                onDeleteFiles: (_) async {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the files card fills the window instead of shrink-wrapping', (tester) async {
    await _pump(tester, height: 800);

    // La lista es la superficie principal de la ventana, y el `Expanded` es lo
    // que se lo da. Si se cae, la tarjeta se ajusta a sus dos filas y la barra
    // de estado deja de estar abajo: queda flotando a media pantalla con el
    // fondo debajo, que es exactamente el hueco que este layout existe para
    // cerrar.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilesBrowser)).height, 800);
  });

  testWidgets('the view toggle swaps the list for the grid', (tester) async {
    await _pump(tester);

    // La vista de lista es la única con cabeceras de columna.
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Fecha'), findsNothing);
    expect(find.text('informe.pdf'), findsOneWidget);
  });

  testWidgets('selecting a file swaps the status bar for the selection bar', (tester) async {
    await _pump(tester);

    expect(find.text('2 archivos · 2.0 MB'), findsOneWidget);

    await tester.tap(find.byTooltip('Seleccionar informe.pdf'));
    await tester.pumpAndSettle();

    // Las dos barras se sustituyen, no se apilan: una que apareciera empujaría
    // la lista hacia arriba justo cuando se está apuntando a una fila.
    expect(find.text('2 archivos · 2.0 MB'), findsNothing);
    expect(find.text('1 seleccionado'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
  });

  testWidgets('the search box filters the list by name', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'notas');
    await tester.pumpAndSettle();

    expect(find.text('notas.txt'), findsOneWidget);
    expect(find.text('informe.pdf'), findsNothing);
    // La cuenta dice de cuántos, o parecería que la carpeta perdió archivos.
    expect(find.text('1 de 2 · 1.2 KB'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Limpiar la búsqueda'), findsOneWidget);
  });

  testWidgets('select all only takes the files the filter is showing', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'notas');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Seleccionar todo'));
    await tester.pumpAndSettle();

    // Con un filtro puesto, arrastrar los archivos ocultos sería una trampa: el
    // botón de eliminar está en esa misma barra.
    expect(find.text('1 seleccionado'), findsOneWidget);
  });

  testWidgets('the narrow window drops the date column, not the size', (tester) async {
    await _pump(tester, narrow: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Tamaño'), findsOneWidget);
    expect(find.text('Fecha'), findsNothing);
  });
}
