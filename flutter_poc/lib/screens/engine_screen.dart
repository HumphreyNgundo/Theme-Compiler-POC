import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/engine_provider.dart';
import '../engine/component_registry.dart';
import '../models/app_definition.dart';

/// The main runtime screen. Hosts:
///   • A [BottomNavigationBar] whose tabs come from [NavigationDef.tabs].
///   • A nested [Navigator] whose routes are built by [ComponentRegistry].
///
/// Sub-screens (e.g. send_money, confirm_payment) are pushed onto the nested
/// navigator so the tab bar stays visible throughout.
class EngineScreen extends StatelessWidget {
  const EngineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineProvider>();
    final appDef = engine.appDef;
    final tabs = appDef.navigation.tabs;

    return Scaffold(
      body: Navigator(
        key: engine.navigatorKey,
        initialRoute: '/${appDef.navigation.initialScreen}',
        onGenerateRoute: (settings) {
          // Strip the leading '/' to get the screen id.
          final screenId = settings.name?.replaceFirst('/', '') ?? '';
          final screenDef = appDef.screen(screenId);
          if (screenDef == null) {
            return MaterialPageRoute(
              builder: (_) => _NotFoundScreen(screenId: screenId),
            );
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => _ScreenView(screen: screenDef),
          );
        },
      ),
      bottomNavigationBar: tabs.isEmpty
          ? null
          : _TabBar(tabs: tabs, currentIndex: engine.currentTab),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.currentIndex});
  final List<TabDef> tabs;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Consumer<EngineProvider>(
      builder: (context, engine, _) {
        return NavigationBar(
          selectedIndex: engine.currentTab,
          onDestinationSelected: engine.switchTab,
          destinations: tabs
              .map(
                (t) => NavigationDestination(
                  icon: Icon(_iconFor(t.icon)),
                  label: t.label,
                ),
              )
              .toList(),
        );
      },
    );
  }

  IconData _iconFor(String name) {
    const m = <String, IconData>{
      'home': Icons.home_rounded,
      'send': Icons.send_rounded,
      'receipt': Icons.receipt_long_rounded,
      'person': Icons.person_rounded,
      'wallet': Icons.account_balance_wallet_rounded,
    };
    return m[name] ?? Icons.circle_outlined;
  }
}

// ── Screen view ───────────────────────────────────────────────────────────────

/// Renders a single [ScreenDef] using [ComponentRegistry].
/// Wires up [onAction] to [EngineProvider.handleAction].
class _ScreenView extends StatelessWidget {
  const _ScreenView({required this.screen});
  final ScreenDef screen;

  @override
  Widget build(BuildContext context) {
    final engine = context.read<EngineProvider>();
    final appDef = engine.appDef;

    // Screens define their own top-level layout (scroll_view, list_view, etc.).
    // If there is exactly one root component, render it directly.
    // If multiple, wrap them in an expanding column.
    final onAction = (ActionDef action) => engine.handleAction(action, context);
    final Widget body;
    if (screen.components.length == 1) {
      body = ComponentRegistry.build(
        def: screen.components.first,
        theme: appDef.theme,
        appDef: appDef,
        onAction: onAction,
      );
    } else {
      body = Column(
        children: screen.components
            .map((c) => ComponentRegistry.build(
                  def: c,
                  theme: appDef.theme,
                  appDef: appDef,
                  onAction: onAction,
                ))
            .toList(),
      );
    }

    if (!screen.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: screen.title != null ? Text(screen.title!) : null,
        backgroundColor: appDef.theme.background,
        foregroundColor: appDef.theme.textPrimary,
        elevation: 0,
      ),
      body: body,
    );
  }
}

// ── 404 fallback ──────────────────────────────────────────────────────────────

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.screenId});
  final String screenId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Screen not found: $screenId',
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
