import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/app.dart';

void main() {
  testWidgets('app builds and exposes its title', (tester) async {
    await tester.pumpWidget(const KioskMindApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'KioskMind');
  });

  testWidgets('home renders the placeholder', (tester) async {
    await tester.pumpWidget(const KioskMindApp());

    expect(find.text('KioskMind'), findsOneWidget);
  });
}
