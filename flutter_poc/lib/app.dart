import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

class ThemeCompilerApp extends StatelessWidget {
  const ThemeCompilerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: provider.config.displayName,
          theme: provider.themeData,
          debugShowCheckedModeBanner: false,
          home: _resolveHome(provider.appState),
        );
      },
    );
  }

  Widget _resolveHome(AppState state) {
    switch (state) {
      case AppState.compiling:
        return const SplashScreen();
      case AppState.login:
        return const LoginScreen();
      case AppState.main:
        return const MainScreen();
    }
  }
}
