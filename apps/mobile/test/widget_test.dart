// Minimal smoke test: the app boots inside a ProviderScope and, with no
// stored session, lands on the splash screen while SessionController
// resolves (there is no backend reachable in this test environment, so it
// stays there — this just guards against startup crashes/provider wiring
// errors).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots and shows a splash indicator', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AmmctApp()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
