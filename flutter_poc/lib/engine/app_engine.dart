import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_definition.dart';

// ---------------------------------------------------------------------------
// Compile step — one line in the splash-screen console
// ---------------------------------------------------------------------------

class CompileStep {
  final String label;
  final bool isComplete;
  final bool isActive;

  const CompileStep({
    required this.label,
    this.isComplete = false,
    this.isActive = false,
  });

  CompileStep copyWith({bool? isComplete, bool? isActive}) => CompileStep(
        label: label,
        isComplete: isComplete ?? this.isComplete,
        isActive: isActive ?? this.isActive,
      );
}

// ---------------------------------------------------------------------------
// Engine progress — streamed during initialization
// ---------------------------------------------------------------------------

class EngineProgress {
  final List<CompileStep> steps;
  final AppDefinition? appDef;
  final ThemeData? themeData;

  bool get isDone => appDef != null;

  double get progress {
    if (steps.isEmpty) return 0;
    return steps.where((s) => s.isComplete).length / steps.length;
  }

  const EngineProgress({required this.steps, this.appDef, this.themeData});
}

// ---------------------------------------------------------------------------
// AppEngine
//
// This is the core of the POC. It:
//  1. Fetches the full app definition JSON from a server (or local mock).
//  2. Parses it into typed Dart models.
//  3. Compiles a Flutter ThemeData from the theme block.
//  4. Streams each step so the splash screen can show a live progress console.
//
// To switch from mock to real API, replace _fetchDefinition() with:
//   final res = await http.get(Uri.parse('https://api.example.com/v1/app'));
//   return jsonDecode(res.body) as Map<String, dynamic>;
//
// The rest of the engine — screen compiler, component registry — operates on
// the parsed AppDefinition and has no knowledge of where the JSON came from.
// ---------------------------------------------------------------------------

class AppEngine {
  static const String _mockAsset = 'mock_api/app_definition.json';

  static const List<CompileStep> _pipeline = [
    CompileStep(label: 'Initializing engine runtime...'),
    CompileStep(label: 'Fetching app definition from server...'),
    CompileStep(label: 'Parsing screen definitions...'),
    CompileStep(label: 'Compiling navigation graph...'),
    CompileStep(label: 'Building component registry...'),
    CompileStep(label: 'Compiling theme tokens...'),
    CompileStep(label: 'Rendering initial frame...'),
  ];

  static List<CompileStep> get initialSteps => List.unmodifiable(_pipeline);

  /// Runs the full initialization pipeline, yielding [EngineProgress] after
  /// each step. The final emission has [EngineProgress.isDone] == true.
  Stream<EngineProgress> initialize() async* {
    final steps = List<CompileStep>.from(_pipeline);

    // Step 0: init
    yield EngineProgress(steps: _activate(steps, 0));
    await _pause(400);
    _done(steps, 0);

    // Step 1: fetch
    yield EngineProgress(steps: _activate(steps, 1));
    final raw = await _fetchDefinition();
    await _pause(700);
    _done(steps, 1);

    // Step 2: parse screens
    yield EngineProgress(steps: _activate(steps, 2));
    final appDef = AppDefinition.fromJson(raw);
    await _pause(400);
    _done(steps, 2);

    // Step 3: navigation graph
    yield EngineProgress(steps: _activate(steps, 3));
    await _pause(350);
    _done(steps, 3);

    // Step 4: component registry
    yield EngineProgress(steps: _activate(steps, 4));
    await _pause(400);
    _done(steps, 4);

    // Step 5: theme
    yield EngineProgress(steps: _activate(steps, 5));
    final themeData = _compileTheme(appDef.theme);
    await _pause(450);
    _done(steps, 5);

    // Step 6: render
    yield EngineProgress(steps: _activate(steps, 6));
    await _pause(350);
    _done(steps, 6);

    yield EngineProgress(
      steps: List.unmodifiable(steps),
      appDef: appDef,
      themeData: themeData,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CompileStep> _activate(List<CompileStep> steps, int i) {
    steps[i] = steps[i].copyWith(isActive: true);
    return List.unmodifiable(steps);
  }

  void _done(List<CompileStep> steps, int i) {
    steps[i] = steps[i].copyWith(isComplete: true, isActive: false);
  }

  Future<void> _pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<Map<String, dynamic>> _fetchDefinition() async {
    try {
      // ── Production replacement ──────────────────────────────────────────
      // import 'package:http/http.dart' as http;
      // final res = await http.get(Uri.parse('https://api.example.com/v1/app'));
      // return jsonDecode(res.body) as Map<String, dynamic>;
      // ───────────────────────────────────────────────────────────────────
      final str = await rootBundle.loadString(_mockAsset);
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Converts a [ThemeDef] into a Flutter [ThemeData].
  /// Every colour, font, shape and component style comes from the JSON.
  ThemeData _compileTheme(ThemeDef t) {
    final colorScheme = ColorScheme(
      brightness: t.darkMode ? Brightness.dark : Brightness.light,
      primary: t.primary,
      onPrimary: Colors.white,
      secondary: t.secondary,
      onSecondary: Colors.white,
      error: t.error,
      onError: Colors.white,
      surface: t.surface,
      onSurface: t.textPrimary,
    );

    final base = TextTheme(
      displayLarge: TextStyle(color: t.textPrimary),
      bodyLarge: TextStyle(color: t.textPrimary),
      bodyMedium: TextStyle(color: t.textSecondary),
    );

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme(t.fontFamily, base);
    } catch (_) {
      textTheme = base;
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,
      textTheme: textTheme,
      cardTheme: CardTheme(
        elevation: 0,
        color: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.primary,
          side: BorderSide(color: t.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.textDisabled),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.textDisabled.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
