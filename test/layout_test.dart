import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filefly/app/theme.dart';
import 'package:filefly/ui/widgets/connect_panel.dart';
import 'package:filefly/ui/widgets/send_panel.dart';

/// The wide layout puts the two top panels in one row and closes them on a
/// single bottom edge.
///
/// This mirrors `_TopPanels`: an `IntrinsicHeight` supplying the bounded height
/// that `stretch` needs, inside a scroll view that would otherwise leave the
/// row unbounded. The pairing is the thing under test — drop either half and
/// the send card silently falls back to shrink-wrapping its content, which is
/// the hole this layout exists to close.
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

    // The connect card is the taller of the two, so a match this size only
    // happens if the send card actually grew.
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
