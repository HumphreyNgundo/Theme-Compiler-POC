import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:theme_compiler_poc/providers/theme_provider.dart';
import 'package:theme_compiler_poc/app.dart';

void main() {
  testWidgets('Splash screen shows on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const ThemeCompilerApp(),
      ),
    );
    // Splash screen should be visible before compilation completes
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
