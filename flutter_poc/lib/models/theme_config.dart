import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Color palette — mirrors ClientColorPalette from sample_files/client_config.dart
// but designed to be deserialized from a JSON API response.
// ---------------------------------------------------------------------------

class AppColorPalette {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color success;
  final Color warning;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color cardGradientStart;
  final Color cardGradientEnd;

  const AppColorPalette({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.cardGradientStart,
    required this.cardGradientEnd,
  });

  factory AppColorPalette.fromJson(Map<String, dynamic> json) {
    return AppColorPalette(
      primary: hexToColor(json['primary'] as String? ?? '#1B8A5A'),
      secondary: hexToColor(json['secondary'] as String? ?? '#2ECC71'),
      background: hexToColor(json['background'] as String? ?? '#F8FAFC'),
      surface: hexToColor(json['surface'] as String? ?? '#FFFFFF'),
      error: hexToColor(json['error'] as String? ?? '#E53E3E'),
      success: hexToColor(json['success'] as String? ?? '#38A169'),
      warning: hexToColor(json['warning'] as String? ?? '#D69E2E'),
      info: hexToColor(json['info'] as String? ?? '#3182CE'),
      textPrimary: hexToColor(json['textPrimary'] as String? ?? '#1A202C'),
      textSecondary: hexToColor(json['textSecondary'] as String? ?? '#718096'),
      textDisabled: hexToColor(json['textDisabled'] as String? ?? '#CBD5E0'),
      cardGradientStart: hexToColor(json['cardGradientStart'] as String? ?? '#1B8A5A'),
      cardGradientEnd: hexToColor(json['cardGradientEnd'] as String? ?? '#27AE60'),
    );
  }

  static Color hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

// ---------------------------------------------------------------------------
// Feature flags — mirrors showAtmLocator / showLoanCalculator etc.
// from ClientConfig. Controls which UI sections are rendered.
// ---------------------------------------------------------------------------

class AppFeatureFlags {
  final bool showAtmLocator;
  final bool showLoanCalculator;
  final bool showScanToPay;
  final bool showMemberRegistration;
  final bool biometricAuth;
  final bool sendMoney;
  final bool paybill;
  final bool buyGoods;
  final bool airtime;

  const AppFeatureFlags({
    this.showAtmLocator = true,
    this.showLoanCalculator = true,
    this.showScanToPay = true,
    this.showMemberRegistration = false,
    this.biometricAuth = true,
    this.sendMoney = true,
    this.paybill = true,
    this.buyGoods = true,
    this.airtime = true,
  });

  factory AppFeatureFlags.fromJson(Map<String, dynamic> json) {
    return AppFeatureFlags(
      showAtmLocator: json['showAtmLocator'] as bool? ?? true,
      showLoanCalculator: json['showLoanCalculator'] as bool? ?? true,
      showScanToPay: json['showScanToPay'] as bool? ?? true,
      showMemberRegistration: json['showMemberRegistration'] as bool? ?? false,
      biometricAuth: json['biometricAuth'] as bool? ?? true,
      sendMoney: json['sendMoney'] as bool? ?? true,
      paybill: json['paybill'] as bool? ?? true,
      buyGoods: json['buyGoods'] as bool? ?? true,
      airtime: json['airtime'] as bool? ?? true,
    );
  }
}

// ---------------------------------------------------------------------------
// Splash config — mirrors SplashScreenConfig from sample_files
// ---------------------------------------------------------------------------

class SplashConfig {
  final Color backgroundColor;
  final int durationMs;

  const SplashConfig({
    required this.backgroundColor,
    this.durationMs = 3000,
  });

  factory SplashConfig.fromJson(Map<String, dynamic> json) {
    return SplashConfig(
      backgroundColor: AppColorPalette.hexToColor(
        json['backgroundColor'] as String? ?? '#1B8A5A',
      ),
      durationMs: json['duration'] as int? ?? 3000,
    );
  }
}

// ---------------------------------------------------------------------------
// Root config — the full API response shape.
// Mirrors ClientConfig from sample_files/client_config.dart.
// ---------------------------------------------------------------------------

class AppThemeConfig {
  final String clientId;
  final String displayName;
  final String tagline;
  final AppColorPalette colors;
  final String fontFamily;
  final bool darkMode;
  final AppFeatureFlags features;
  final SplashConfig splashConfig;

  const AppThemeConfig({
    required this.clientId,
    required this.displayName,
    required this.tagline,
    required this.colors,
    required this.fontFamily,
    required this.darkMode,
    required this.features,
    required this.splashConfig,
  });

  factory AppThemeConfig.fromJson(Map<String, dynamic> json) {
    return AppThemeConfig(
      clientId: json['clientId'] as String? ?? 'default',
      displayName: json['displayName'] as String? ?? 'Finance App',
      tagline: json['tagline'] as String? ?? '',
      colors: AppColorPalette.fromJson(
        json['colors'] as Map<String, dynamic>? ?? {},
      ),
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      darkMode: json['darkMode'] as bool? ?? false,
      features: AppFeatureFlags.fromJson(
        json['features'] as Map<String, dynamic>? ?? {},
      ),
      splashConfig: SplashConfig.fromJson(
        json['splashConfig'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Hard-coded fallback used before the API response is received.
  static const AppThemeConfig fallback = AppThemeConfig(
    clientId: 'default',
    displayName: 'Finance App',
    tagline: 'Your trusted finance partner',
    colors: AppColorPalette(
      primary: Color(0xFF1B8A5A),
      secondary: Color(0xFF2ECC71),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      error: Color(0xFFE53E3E),
      success: Color(0xFF38A169),
      warning: Color(0xFFD69E2E),
      info: Color(0xFF3182CE),
      textPrimary: Color(0xFF1A202C),
      textSecondary: Color(0xFF718096),
      textDisabled: Color(0xFFCBD5E0),
      cardGradientStart: Color(0xFF1B8A5A),
      cardGradientEnd: Color(0xFF27AE60),
    ),
    fontFamily: 'Roboto',
    darkMode: false,
    features: AppFeatureFlags(),
    splashConfig: SplashConfig(
      backgroundColor: Color(0xFF1B8A5A),
    ),
  );
}
