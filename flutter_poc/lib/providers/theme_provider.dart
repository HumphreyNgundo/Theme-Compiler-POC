import 'package:flutter/material.dart';
import '../models/theme_config.dart';
import '../services/theme_compiler_service.dart';

enum AppState { compiling, login, main }

/// Central state holder. Drives the three-phase app lifecycle:
///   compiling → login → main
///
/// Consumed by [ThemeCompilerApp] to swap the root screen and by
/// MaterialApp to apply the compiled [themeData].
class ThemeProvider extends ChangeNotifier {
  AppThemeConfig _config = AppThemeConfig.fallback;
  ThemeData _themeData = ThemeData.light(useMaterial3: true);
  AppState _appState = AppState.compiling;
  List<CompileStep> _steps = ThemeCompilerService.initialSteps;
  double _progress = 0;

  AppThemeConfig get config => _config;
  ThemeData get themeData => _themeData;
  AppState get appState => _appState;
  List<CompileStep> get compileSteps => _steps;
  double get compileProgress => _progress;

  /// Called once from [SplashScreen.initState]. Streams compilation progress
  /// and transitions to [AppState.login] when done.
  Future<void> compileTheme() async {
    final service = ThemeCompilerService();
    await for (final progress in service.compile()) {
      _steps = progress.steps;
      _progress = progress.progress;
      if (progress.isDone) {
        _config = progress.result!.config;
        _themeData = progress.result!.themeData;
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        _appState = AppState.login;
      }
      notifyListeners();
    }
  }

  void onLoginSuccess() {
    _appState = AppState.main;
    notifyListeners();
  }

  void onLogout() {
    _appState = AppState.login;
    notifyListeners();
  }
}
