import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

// Define the data models
class WelcomeCarouselItem {
  final String? title;
  final String? subtitle;
  final String? iconPath;
  final String? featureText;

  const WelcomeCarouselItem({
    this.title,
    this.subtitle,
    this.iconPath,
    this.featureText,
  });
}

class ClientConfig {
  final String clientId;
  final String displayName;
  final ClientColorPalette colors;
  final String? logoAsset;
  final String? fontFamily;
  final SplashScreenConfig splashConfig;
  final int appIdleTimeout; // in milliseconds
  final bool showAtmLocator;
  final bool showLoanCalculator;
  final bool showScanToPay;
  final bool showMemberRegistration;
  final bool forceUpdate;
  final List<WelcomeCarouselItem>? customCarouselItems;

  const ClientConfig({
    required this.clientId,
    required this.displayName,
    required this.colors,
    this.logoAsset,
    this.fontFamily,
    required this.splashConfig,
    this.appIdleTimeout = 300000, // Default to 5 minutes
    this.showAtmLocator = true,
    this.showLoanCalculator = true,
    this.showScanToPay = true,
    this.showMemberRegistration = false,
    this.forceUpdate = true,
    this.customCarouselItems,
  });
}

class ClientColorPalette {
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
  final Color modalBackground;
  final Color unselectedNavItem; // For navigation and UI elements
  final Color fontColor;
  final Color? accountCardColor;
  final List<Color>? accountCardColors;

  const ClientColorPalette({
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
    required this.modalBackground,
    required this.unselectedNavItem,
    this.fontColor = const Color(0xFF000000),
    this.accountCardColor,
    this.accountCardColors,
  });
}

class SplashScreenConfig {
  final String type; // "image" or "video"
  final String assetPath;
  final Duration duration;
  final Color? backgroundColor;
  final bool showLogo;
  final String? overlayLogoPath;
  final String? fallbackImagePath;

  const SplashScreenConfig({
    required this.type,
    required this.assetPath,
    required this.duration,
    this.backgroundColor,
    this.showLogo = true,
    this.overlayLogoPath,
    this.fallbackImagePath,
  });
}

// Singleton manager - only manages state, no initialization logic
class ClientThemeManager {
  static final ClientThemeManager _instance = ClientThemeManager._internal();
  factory ClientThemeManager() => _instance;
  ClientThemeManager._internal();

  // Default client ID
  static const String defaultClientId = '999';

  // Registry of all available client configurations
  final Map<String, ClientConfig> _clientConfigs = {};

  // Current selected client ID
  String _currentClientId = defaultClientId;

  // Flag to ensure initialization happens only once
  bool _isInitialized = false;

  // Getters
  ClientConfig get currentClientConfig =>
      _clientConfigs[_currentClientId] ?? _clientConfigs[defaultClientId]!;

  ClientColorPalette get colors => currentClientConfig.colors;

  String get currentClientId => _currentClientId;

  bool get isInitialized => _isInitialized;

  // Register a client configuration
  void registerClientConfig(String clientId, ClientConfig config) {
    _clientConfigs[clientId] = config;
    AppLogger.debug('Registered client configuration: $clientId');
  }

  // Set the current client
  bool setClient(String clientId) {
    if (_clientConfigs.containsKey(clientId)) {
      _currentClientId = clientId;
      AppLogger.info('Set client theme to: $clientId');
      return true;
    } else {
      AppLogger.warning('Client ID "$clientId" not found, using default theme');
      _currentClientId = defaultClientId;
      return false;
    }
  }

  void updateClientPaths() {
    if (_currentClientId != defaultClientId && _clientConfigs.containsKey(_currentClientId)) {
      var config = _clientConfigs[_currentClientId]!;

      // Only update if using generic paths
      if (config.logoAsset?.contains('/999/') == true) {
        // Create updated config
        var updatedConfig = ClientConfig(
          clientId: config.clientId,
          displayName: config.displayName,
          colors: config.colors,
          logoAsset: 'assets/logos/$_currentClientId/logo.png',
          fontFamily: config.fontFamily,
          splashConfig: SplashScreenConfig(
            type: config.splashConfig.type,
            assetPath: config.splashConfig.type == "video"
                ? 'assets/videos/$_currentClientId/splash.mp4'
                : 'assets/images/$_currentClientId/splash.png',
            duration: config.splashConfig.duration,
            backgroundColor: config.splashConfig.backgroundColor,
            showLogo: config.splashConfig.showLogo,
            overlayLogoPath: config.splashConfig.overlayLogoPath,
            fallbackImagePath: 'assets/logos/logo.png',
          ),
          appIdleTimeout: config.appIdleTimeout,
          showAtmLocator: config.showAtmLocator,
          showLoanCalculator: config.showLoanCalculator,
          showScanToPay: config.showScanToPay,
          showMemberRegistration: config.showMemberRegistration,
          forceUpdate: config.forceUpdate,
          customCarouselItems: config.customCarouselItems,
        );

        // Replace the config
        _clientConfigs[_currentClientId] = updatedConfig;
        AppLogger.debug('Updated paths for client $_currentClientId');
      }
    }
  }

  // Clear all configurations (useful for testing)
  void clearConfigurations() {
    _clientConfigs.clear();
    _currentClientId = defaultClientId;
    _isInitialized = false;
  }

  // Mark as initialized
  void markAsInitialized() {
    _isInitialized = true;
  }

  // Check if a client is registered
  bool hasClient(String clientId) {
    return _clientConfigs.containsKey(clientId);
  }

  // Initialize the client based on priority:
  // 1. Build argument (flavor)
  // 2. Environment variable
  // 3. Default
  void initializeClient() {
    // Check build argument first (for flavors)
    final buildArgClientId = const String.fromEnvironment('CLIENT_ID', defaultValue: '');

    if (buildArgClientId.isNotEmpty) {
      AppLogger.info('CLIENT_ID from build argument: $buildArgClientId');
      setClient(buildArgClientId);
      return;
    }

    // Then check .env file (if available)
    try {
      final envClientId = dotenv.get('CLIENT_ID', fallback: '');
      if (envClientId.isNotEmpty) {
        AppLogger.info('CLIENT_ID from .env: $envClientId');
        setClient(envClientId);
        return;
      }
    } catch (e) {
      AppLogger.warning('No .env file available, using default CLIENT_ID', e);
    }

    // Fall back to default
    AppLogger.info('Using default CLIENT_ID: $defaultClientId');
    setClient(defaultClientId);
  }
} 