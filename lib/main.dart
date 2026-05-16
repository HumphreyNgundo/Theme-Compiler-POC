import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/engine_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => EngineProvider(),
      child: const ThemeCompilerApp(),
    ),
  );
}
