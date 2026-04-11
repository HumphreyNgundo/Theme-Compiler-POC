import 'package:flutter/material.dart';
import '../engine/app_engine.dart';
import '../models/app_definition.dart';

enum EngineState { loading, ready }

/// Central state for the engine.
/// Drives three lifecycles:
///   loading  → app definition is being fetched and compiled
///   ready    → app is running; isAuthenticated + currentTab control routing
class EngineProvider extends ChangeNotifier {
  // ── Compile-phase state ───────────────────────────────────────────────────
  EngineState _state = EngineState.loading;
  List<CompileStep> _steps = AppEngine.initialSteps;
  double _progress = 0;

  // ── Runtime state ─────────────────────────────────────────────────────────
  AppDefinition? _appDef;
  ThemeData? _themeData;
  bool _isAuthenticated = false;
  int _currentTab = 0;

  // Navigator key for push-based navigation (sub-screens from Payments etc.)
  final navigatorKey = GlobalKey<NavigatorState>();

  // ── Getters ───────────────────────────────────────────────────────────────
  EngineState get state => _state;
  List<CompileStep> get steps => _steps;
  double get progress => _progress;
  AppDefinition get appDef => _appDef!;
  ThemeData get themeData => _themeData ?? ThemeData.light(useMaterial3: true);
  bool get isAuthenticated => _isAuthenticated;
  int get currentTab => _currentTab;
  bool get isReady => _state == EngineState.ready;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called once from [SplashScreen]. Streams compile progress until the
  /// full [AppDefinition] is available, then transitions to [EngineState.ready].
  Future<void> initialize() async {
    final engine = AppEngine();
    await for (final p in engine.initialize()) {
      _steps = p.steps;
      _progress = p.progress;
      if (p.isDone) {
        _appDef = p.appDef;
        _themeData = p.themeData;
        notifyListeners();
        // Brief pause so the user sees the completed console before the app loads
        await Future<void>.delayed(const Duration(milliseconds: 800));
        _state = EngineState.ready;
      }
      notifyListeners();
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  void authenticate() {
    _isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentTab = 0;
    notifyListeners();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void switchTab(int index) {
    if (_currentTab == index) return;
    final nav = navigatorKey.currentState;
    if (nav != null && _appDef != null && index < _appDef!.navigation.tabs.length) {
      final screenId = _appDef!.navigation.tabs[index].screenId;
      // Pop any sub-screens, then replace the current root with the new tab's screen.
      nav.popUntil((r) => r.isFirst);
      nav.pushReplacementNamed('/$screenId');
    }
    _currentTab = index;
    notifyListeners();
  }

  void handleAction(ActionDef action, BuildContext context) {
    switch (action.type) {

      case 'authenticate':
        authenticate();

      case 'logout':
        logout();

      case 'go_back':
        navigatorKey.currentState?.pop();

      case 'navigate':
        final screenId = action.screen;
        if (screenId == null) return;
        // Check if the target is a top-level tab screen
        final tabIndex = _tabIndexFor(screenId);
        if (tabIndex != null) {
          switchTab(tabIndex);
        } else {
          // Push as a sub-screen
          navigatorKey.currentState?.pushNamed('/$screenId');
        }

      case 'navigate_tab':
        final tab = action.tab;
        if (tab != null) switchTab(tab);

      case 'share':
        // In production: use share_plus package
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt shared!')),
        );
    }
  }

  int? _tabIndexFor(String screenId) {
    if (_appDef == null) return null;
    final tabs = _appDef!.navigation.tabs;
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].screenId == screenId) return i;
    }
    return null;
  }
}
