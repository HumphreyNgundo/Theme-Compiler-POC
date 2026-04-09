import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/theme_config.dart';

// ---------------------------------------------------------------------------
// Step model — each line shown in the compiler console on the splash screen
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
// Progress model — emitted on each step of the Stream
// ---------------------------------------------------------------------------

class CompiledAppTheme {
  final AppThemeConfig config;
  final ThemeData themeData;

  const CompiledAppTheme({required this.config, required this.themeData});
}

class CompileProgress {
  final List<CompileStep> steps;
  final CompiledAppTheme? result;

  bool get isDone => result != null;

  double get progress {
    if (steps.isEmpty) return 0;
    return steps.where((s) => s.isComplete).length / steps.length;
  }

  const CompileProgress({required this.steps, this.result});
}

// ---------------------------------------------------------------------------
// Theme Compiler Service
//
// Simulates the app "build cycle" — fetching UI configuration from an API
// and compiling it into a Flutter ThemeData at runtime.
//
// In production replace [_mockAssetPath] with an HTTP GET:
//   import 'package:http/http.dart' as http;
//   final response = await http.get(Uri.parse('https://api.example.com/v1/theme'));
//   return jsonDecode(response.body) as Map<String, dynamic>;
// ---------------------------------------------------------------------------

class ThemeCompilerService {
  static const String _mockAssetPath = 'mock_api/theme_config.json';

  static const List<CompileStep> _steps = [
    CompileStep(label: 'Initializing runtime...'),
    CompileStep(label: 'Fetching theme configuration...'),
    CompileStep(label: 'Parsing color tokens...'),
    CompileStep(label: 'Compiling typography...'),
    CompileStep(label: 'Building component styles...'),
    CompileStep(label: 'Applying feature flags...'),
    CompileStep(label: 'Finalizing...'),
  ];

  static List<CompileStep> get initialSteps => List.unmodifiable(_steps);

  /// Runs the full compilation pipeline, yielding [CompileProgress] on each
  /// step. The final emission has [CompileProgress.isDone] == true and
  /// contains the fully compiled [CompiledAppTheme].
  Stream<CompileProgress> compile() async* {
    final steps = List<CompileStep>.from(_steps);

    // Step 0: Initialize
    yield CompileProgress(steps: _activate(steps, 0));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _complete(steps, 0);

    // Step 1: Fetch from API
    yield CompileProgress(steps: _activate(steps, 1));
    final rawJson = await _fetchConfig();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _complete(steps, 1);

    // Step 2: Parse colors
    yield CompileProgress(steps: _activate(steps, 2));
    final config = AppThemeConfig.fromJson(rawJson);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _complete(steps, 2);

    // Step 3: Compile typography
    yield CompileProgress(steps: _activate(steps, 3));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _complete(steps, 3);

    // Step 4: Build component styles
    yield CompileProgress(steps: _activate(steps, 4));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _complete(steps, 4);

    // Step 5: Apply feature flags
    yield CompileProgress(steps: _activate(steps, 5));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _complete(steps, 5);

    // Step 6: Finalize
    yield CompileProgress(steps: _activate(steps, 6));
    final themeData = _buildTheme(config);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _complete(steps, 6);

    yield CompileProgress(
      steps: List.unmodifiable(steps),
      result: CompiledAppTheme(config: config, themeData: themeData),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CompileStep> _activate(List<CompileStep> steps, int i) {
    steps[i] = steps[i].copyWith(isActive: true);
    return List.unmodifiable(steps);
  }

  void _complete(List<CompileStep> steps, int i) {
    steps[i] = steps[i].copyWith(isComplete: true, isActive: false);
  }

  Future<Map<String, dynamic>> _fetchConfig() async {
    try {
      // POC: loads from bundled mock asset.
      // Production: replace with http.get(Uri.parse(_apiUrl)).
      final jsonString = await rootBundle.loadString(_mockAssetPath);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{}; // fall back to defaults
    }
  }

  // Builds a fully configured Flutter ThemeData from the parsed AppThemeConfig.
  ThemeData _buildTheme(AppThemeConfig config) {
    final c = config.colors;

    final colorScheme = ColorScheme(
      brightness: config.darkMode ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: Colors.white,
      secondary: c.secondary,
      onSecondary: Colors.white,
      error: c.error,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    final baseTextTheme = TextTheme(
      displayLarge: TextStyle(color: c.textPrimary),
      displayMedium: TextStyle(color: c.textPrimary),
      bodyLarge: TextStyle(color: c.textPrimary),
      bodyMedium: TextStyle(color: c.textSecondary),
      labelSmall: TextStyle(color: c.textDisabled),
    );

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme(config.fontFamily, baseTextTheme);
    } catch (_) {
      textTheme = baseTextTheme;
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      textTheme: textTheme,
      cardTheme: CardTheme(
        elevation: 0,
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.textDisabled),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.textDisabled.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
