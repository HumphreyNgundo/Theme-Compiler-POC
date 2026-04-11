import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppDefinition — the root document the server sends.
// Every screen, dialog, navigation structure and theme is defined here.
// The Flutter app contains NO hardcoded screen logic; it is a pure runtime
// that compiles this definition into widgets.
// ---------------------------------------------------------------------------

class AppDefinition {
  final String version;
  final String appName;
  final String tagline;
  final ThemeDef theme;
  final NavigationDef navigation;
  final Map<String, ScreenDef> screens;

  const AppDefinition({
    required this.version,
    required this.appName,
    required this.tagline,
    required this.theme,
    required this.navigation,
    required this.screens,
  });

  factory AppDefinition.fromJson(Map<String, dynamic> json) {
    return AppDefinition(
      version: json['version'] as String? ?? '1.0',
      appName: json['appName'] as String? ?? 'App',
      tagline: json['tagline'] as String? ?? '',
      theme: ThemeDef.fromJson(json['theme'] as Map<String, dynamic>? ?? {}),
      navigation: NavigationDef.fromJson(
          json['navigation'] as Map<String, dynamic>? ?? {}),
      screens: (json['screens'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, ScreenDef.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  ScreenDef? screen(String id) => screens[id];
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

class ThemeDef {
  final Map<String, String> colors;
  final String fontFamily;
  final bool darkMode;

  const ThemeDef({
    required this.colors,
    required this.fontFamily,
    required this.darkMode,
  });

  factory ThemeDef.fromJson(Map<String, dynamic> json) {
    return ThemeDef(
      colors: (json['colors'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      darkMode: json['darkMode'] as bool? ?? false,
    );
  }

  /// Resolve a colour value that may be a `$variable` reference or a literal hex.
  Color resolve(String value) {
    if (value.startsWith(r'$')) {
      final hex = colors[value.substring(1)];
      return hex != null ? _hex(hex) : Colors.black;
    }
    if (value.startsWith('#')) return _hex(value);
    return Colors.black;
  }

  static Color _hex(String hex) {
    final c = hex.replaceAll('#', '');
    return Color(int.parse('FF$c', radix: 16));
  }

  // Convenience getters
  Color get primary => resolve(r'$primary');
  Color get secondary => resolve(r'$secondary');
  Color get background => resolve(r'$background');
  Color get surface => resolve(r'$surface');
  Color get error => resolve(r'$error');
  Color get textPrimary => resolve(r'$textPrimary');
  Color get textSecondary => resolve(r'$textSecondary');
  Color get textDisabled => resolve(r'$textDisabled');
  Color get cardStart => resolve(r'$cardStart');
  Color get cardEnd => resolve(r'$cardEnd');
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

class NavigationDef {
  final String authScreen;
  final String initialScreen;
  final List<TabDef> tabs;

  const NavigationDef({
    required this.authScreen,
    required this.initialScreen,
    required this.tabs,
  });

  factory NavigationDef.fromJson(Map<String, dynamic> json) {
    return NavigationDef(
      authScreen: json['authScreen'] as String? ?? 'login',
      initialScreen: json['initialScreen'] as String? ?? 'home',
      tabs: (json['tabs'] as List<dynamic>? ?? [])
          .map((t) => TabDef.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TabDef {
  final String screenId;
  final String label;
  final String icon;

  const TabDef({
    required this.screenId,
    required this.label,
    required this.icon,
  });

  factory TabDef.fromJson(Map<String, dynamic> json) => TabDef(
        screenId: json['screenId'] as String,
        label: json['label'] as String,
        icon: json['icon'] as String,
      );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ScreenDef {
  final String id;
  final String? title;
  final bool showAppBar;
  final List<ComponentDef> components;

  const ScreenDef({
    required this.id,
    this.title,
    this.showAppBar = false,
    required this.components,
  });

  factory ScreenDef.fromJson(Map<String, dynamic> json) => ScreenDef(
        id: json['id'] as String,
        title: json['title'] as String?,
        showAppBar: json['showAppBar'] as bool? ?? false,
        components: (json['components'] as List<dynamic>? ?? [])
            .map((c) => ComponentDef.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Component — a single node in the UI tree
// ---------------------------------------------------------------------------

class ComponentDef {
  final String type;
  final Map<String, dynamic> props;
  final List<ComponentDef>? children;

  const ComponentDef({
    required this.type,
    this.props = const {},
    this.children,
  });

  factory ComponentDef.fromJson(Map<String, dynamic> json) => ComponentDef(
        type: json['type'] as String,
        props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
        children: (json['children'] as List<dynamic>?)
            ?.map((c) => ComponentDef.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  T? prop<T>(String key) => props[key] as T?;
  T propOr<T>(String key, T fallback) => (props[key] as T?) ?? fallback;
}

// ---------------------------------------------------------------------------
// Action — what happens when the user taps a button
// ---------------------------------------------------------------------------

class ActionDef {
  final String type;
  final Map<String, dynamic> params;

  const ActionDef({required this.type, required this.params});

  factory ActionDef.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final params = Map<String, dynamic>.from(json)..remove('type');
    return ActionDef(type: type, params: params);
  }

  static ActionDef? tryParse(dynamic raw) {
    if (raw is Map<String, dynamic>) return ActionDef.fromJson(raw);
    return null;
  }

  String? get screen => params['screen'] as String?;
  int? get tab => params['tab'] as int?;
}
