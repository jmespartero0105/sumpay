import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sumpay/core/app.dart';

void main() {
  testWidgets('SUMPAY app boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SumpayApp()),
    );

    // First frame renders the branded splash without throwing.
    await tester.pump();
    expect(find.text('SUMPAY'), findsWidgets);
  });
}
