import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/engine_provider.dart';
import 'engine/component_registry.dart';
import 'models/app_definition.dart';
import 'screens/splash_screen.dart';
import 'screens/engine_screen.dart';

/// Root widget. Delegates all routing to [EngineProvider].
///
/// State machine:
///   loading               → SplashScreen (compile console)
///   ready + !authed       → auth screen (login, no tab bar)
///   ready + authed        → EngineScreen (tab shell with nested navigator)
class ThemeCompilerApp extends StatelessWidget {
  const ThemeCompilerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EngineProvider>(
      builder: (context, engine, _) {
        return MaterialApp(
          title: engine.isReady ? engine.appDef.appName : 'Loading…',
          theme: engine.themeData,
          debugShowCheckedModeBanner: false,
          home: _resolveHome(engine),
        );
      },
    );
  }

  Widget _resolveHome(EngineProvider engine) {
    if (!engine.isReady) return const SplashScreen();
    if (!engine.isAuthenticated) return const _AuthShell();
    return const EngineScreen();
  }
}

// ── Auth shell ────────────────────────────────────────────────────────────────

/// Renders the auth screen from the JSON definition.
/// A nested [Navigator] is provided so any "navigate" actions during the auth
/// flow (e.g. forgot-password) work without a tab bar.
class _AuthShell extends StatelessWidget {
  const _AuthShell({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.read<EngineProvider>();
    final appDef = engine.appDef;
    final authId = appDef.navigation.authScreen;

    return Navigator(
      key: engine.navigatorKey,
      initialRoute: '/$authId',
      onGenerateRoute: (settings) {
        final id = settings.name?.replaceFirst('/', '') ?? authId;
        final screenDef = appDef.screen(id);
        return MaterialPageRoute(
          settings: settings,
          builder: (ctx) => _renderScreen(ctx, engine, appDef, screenDef, id),
        );
      },
    );
  }

  Widget _renderScreen(
    BuildContext context,
    EngineProvider engine,
    AppDefinition appDef,
    ScreenDef? screenDef,
    String id,
  ) {
    if (screenDef == null) {
      return Scaffold(
        body: Center(child: Text('Screen "$id" not found')),
      );
    }

    final onAction = (ActionDef action) => engine.handleAction(action, context);
    final Widget body;
    if (screenDef.components.length == 1) {
      body = ComponentRegistry.build(
        def: screenDef.components.first,
        theme: appDef.theme,
        appDef: appDef,
        onAction: onAction,
      );
    } else {
      body = Column(
        children: screenDef.components
            .map((c) => ComponentRegistry.build(
                  def: c,
                  theme: appDef.theme,
                  appDef: appDef,
                  onAction: onAction,
                ))
            .toList(),
      );
    }

    if (!screenDef.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: screenDef.title != null ? Text(screenDef.title!) : null,
        backgroundColor: appDef.theme.background,
        foregroundColor: appDef.theme.textPrimary,
        elevation: 0,
      ),
      body: body,
    );
  }
}
