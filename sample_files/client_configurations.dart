import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'client_config.dart';
import '../utils/font_helper.dart';

// This file is responsible for registering all client configurations
class ClientConfigurations {
  // Private constructor to prevent instantiation
  ClientConfigurations._();

  // Register all known client configurations
  static void registerAllClients() {
    final manager = ClientThemeManager();

    // Register default client (999)
    _registerDefaultClient(manager);

    //Register Nafasi Sacco(106)
    _registerNafasiClient(manager);

    //Register SmartLife Client(96)
    _registerSmartlifeClient(manager);

    //Register Thamani Sacco(97)
    _registerThamaniClient(manager);

    //Register Kencream Sacco(108)
    _registerKencreamClient(manager);

    //Register jogoo client(105)
    _registerJogooClient(manager);

    // Register Mentor Sacco (38)
    _registerMentorClient(manager);

    // Register Amica Sacco (116)
    _registerAmicaClient(manager);

    //Register Mwietheri Sacco(88)
    _registerMwietheriClient(manager);

    //Register Lengo Sacco(109)
    _registerLengoClient(manager);

    //Register shirika(107)
    _registerShirikaSacco(manager);

    //Register Tabasuri sacco(98)
    _registerTabasuriClient(manager);

    // Register Tower Sacco (81)
    _registerTowerClient(manager);

    //Register Kenchic Sacco(112)
    _registerKenchicClient(manager);

    // Register Magadi Sacco (120)
    _registerMagadiClient(manager);

    // Register M-BORESHA (93)
    _registerMBoreshaClient(manager);

    //Register Gdc-Sacco(77)
    _registerGdcClient(manager);

    //Register Imarika Sacco(39)
    _registerImarikaClient(manager);

    //Register Fariji Sacco (113)
    _registerFarijiClient(manager);

    // Register Shelloyees Sacco (114)
    _registerShelloyeesClient(manager);

    // Register M-Chai Sacco (90)
    _registerMchaiClient(manager);

    //Register Kenyatta Matibabu Sacco (115)
    _registerMatibabuSaccoClient(manager);

    //Register MaishaBora Sacco (99)
    _registerMaishaBoraClient(manager);

    // Register Ollin Sacco (54)
    _registerOllinClient(manager);

    //Register Qwetu Sacco
    _registerQwetuClient(manager);

    //Register Baraka Yetu Sacco(92)
    _registerBarakaClient(manager);

    //Register Nawiri Client(68)
    _registerNawiriClient(manager);

    //Register ports sacco(104)
    _registerPortsSaccoClient(manager);

    //Register Ngarisha Sacco(51)
    _registerNgarishaClient(manager);

    //Register Egerton Sacco(60)
    _registerEgertonClient(manager);

    //Register Golden Pillar sacco(95)
    _registerGoldenPillarClient(manager);

    //Register Mchipuka Sacco(85)
    _registerMchipukaClient(manager);

    //Register Tai Sacco(52)
    _registerTaiClient(manager);

    //Register Bandari Sacco(89)
    _registerBandariClient(manager);

    // Register additional clients as needed
    // You can also call registerDynamicClients() here for other IDs
  }

  // Tangazoletu Sacco configuration (Client ID: 999)
  static void _registerDefaultClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '999',
        ClientConfig(
          clientId: '999',
          displayName: 'Tangazoletu Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFF3987CA), // Blue primary
            secondary: Color(0xFF8CC543), // Green secondary
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/999/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/999/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/999/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: true,
          showLoanCalculator: true,
          showScanToPay: true,
        ));
  }

  static void _registerShelloyeesClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '114',
        ClientConfig(
          clientId: '114',
          displayName: 'SHELLOYEES SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF1068B2),
            primary: Color(0xFF1B8F45),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFFFFE03C),
            unselectedNavItem: Color(0xFF38B612),
            fontColor: Color(0xFF5170ff),
            accountCardColors: [
              Color(0xFF38B612),
              Color(0xFFFFE03C),
              Color(0xFF5170FF),
            ],
          ),
          logoAsset: 'assets/logos/114/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/114/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/114/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerSmartlifeClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '96',
        ClientConfig(
          clientId: '96',
          displayName: 'SMARTLIFE SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF22AAE2),
            primary: Color(0xFFF5821F),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF221D88),
          ),
          logoAsset: 'assets/logos/96/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/96/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/96/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }


  static void _registerGoldenPillarClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '95',
        ClientConfig(
          clientId: '95',
          displayName: 'GOLDEN PILLAR SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF241F21),
            primary: Color(0xFFD39F25),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF221D88),
          ),
          logoAsset: 'assets/logos/95/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/95/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/95/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }


  static void _registerBarakaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '92',
        ClientConfig(
          clientId: '92',
          displayName: 'BARAKA YETU SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF3CA851),
            primary: Color(0xFFE92F9D),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF00A850),
            accountCardColors: [
              Color(0xFF3CA851),
              Color(0xFFE92F9D),
            ],
          ),
          logoAsset: 'assets/logos/92/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/92/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/92/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
          showMemberRegistration: true,
        ));
  }

  static void _registerKenchicClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '112',
        ClientConfig(
          clientId: '112',
          displayName: 'KENCHIC SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF213E9A),
            primary: Color(0xFFEDB941),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/112/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/112/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/112/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerLengoClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '109',
        ClientConfig(
          clientId: '109',
          displayName: 'LENGO SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF0000FF),
            primary: Color(0xFF0000FF),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFFEEEE22),
            accountCardColor:Color(0xFF0000FF),
          ),
          logoAsset: 'assets/logos/109/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/109/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/109/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  static void _registerNgarishaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '51',
        ClientConfig(
          clientId: '51',
          displayName: 'NGARISHA SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF1E3A8A),
            primary: Color(0xFF1E3A8A),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/51/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/51/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/51/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerTabasuriClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '98',
        ClientConfig(
          clientId: '98',
          displayName: 'TABASURI DT SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF0695D7),
            primary: Color(0xFF0695D7),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF223070),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/98/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/98/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/98/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerNawiriClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '68',
        ClientConfig(
          clientId: '68',
          displayName: 'NAWIRI SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFFEC2230),
            primary: Color(0xFFEC2230),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF223070),
            unselectedNavItem: Color(0xFFEC2230),
            fontColor: Color(0xFF000000),
            accountCardColor:  Color(0xFFEC2230),
          ),
          logoAsset: 'assets/logos/68/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/68/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/68/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerPortsSaccoClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '104',
        ClientConfig(
          clientId: '104',
          displayName: 'PORTS SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFFEB651E),
            primary: Color(0xFF22A9B7),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/104/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/104/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/104/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
          showMemberRegistration: true,
        ));
  }

  static void _registerMatibabuSaccoClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '115',
        ClientConfig(
          clientId: '115',
          displayName: 'Kenyatta Matibabu Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF2D5F5D),
            primary: Color(0xFF07524A),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/115/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/115/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/115/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerTowerClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '81',
        ClientConfig(
          clientId: '81',
          displayName: 'Tower Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFF00A651), // Original green primary
            secondary: Color(0xFFEC008C), // Original pink secondary
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/splash.png',
            duration: const Duration(seconds: 3),
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // Mentor Sacco configuration (Client ID: 38)
  static void _registerMentorClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '38',
        ClientConfig(
          clientId: '38',
          displayName: 'Mentor Cash',
          colors: ClientColorPalette(
            primary: Color(0xFFF38B32), // Orange
            secondary: Color(0xFF067C4B), // Green
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/38/logo.png',
          fontFamily: GoogleFonts.nunitoSans().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/38/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/38/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // shirika configuration (Client ID: 107)
  static void _registerShirikaSacco(ClientThemeManager manager) {
    manager.registerClientConfig(
        '107',
        ClientConfig(
          clientId: '107',
          displayName: 'SHIRIKA SACCO',
          colors: ClientColorPalette(
            primary: Color(0xFF81D742),
            secondary: Color(0xFF63D611),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/107/logo.png',
          fontFamily: GoogleFonts.nunitoSans().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/107/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/107/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  static void _registerMwietheriClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '88',
        ClientConfig(
          clientId: '88',
          displayName: 'MWIETHERI SACCO',
          colors: ClientColorPalette(
            secondary: Color(0xFF01B169),
            primary: Color(0xFF444444),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779),
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF8cc543),
          ),
          logoAsset: 'assets/logos/88/logo.png',
          fontFamily: GoogleFonts.lato().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/88/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/88/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  // Fariji Sacco configuration (Client ID: 113)
  static void _registerFarijiClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '113',
        ClientConfig(
          clientId: '113',
          displayName: 'Fariji Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFF009640),
            secondary: Color(0xFF00AEEF),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/113/logo.png',
          fontFamily: GoogleFonts.nunitoSans().fontFamily!,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/113/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/113/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // Amica Sacco configuration (Client ID: 116)
  static void _registerAmicaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '116',
        ClientConfig(
          clientId: '116',
          displayName: 'Amica Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFF2648B6), // Blue
            secondary: Color(0xFF87CEFA), // Light Blue
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/116/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type:
            "image", // Can be changed to "video" if you have splash videos
            assetPath: 'assets/images/116/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/116/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  // Imarika Sacco configuration (Client ID: 39)
  static void _registerImarikaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '39',
        ClientConfig(
          clientId: '39',
          displayName: 'Imarika Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFFE55103),
            secondary: Color(0xFF1C86C2),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF1C86C2), // Consistent modal background
            unselectedNavItem: Color(0xFF1C86C2), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/39/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type:
            "image", // Can be changed to "video" if you have splash videos
            assetPath: 'assets/images/39/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/39/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
          customCarouselItems: const [
            WelcomeCarouselItem(
              title: "Ready to change\nthe way you\nBANK?",
            ),
          ],
        ));
  }

  // Magadi Sacco configuration (Client ID: 120)
  static void _registerMagadiClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '120',
        ClientConfig(
          clientId: '120',
          displayName: 'Magadi Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF234e87), // Primary color #234e87
            primary: Color(0xFF9b3915), // Secondary color #9b3915
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/120/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/120/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/120/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  // MaishaBora Sacco configuration (Client ID: 99)
  static void _registerMaishaBoraClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '99',
        ClientConfig(
          clientId: '99',
          displayName: 'Maisha Bora Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFFBDD63C),
            primary:  Color(0xFF136A3E),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF000000),
            accountCardColor:Color(0xFF146A40),
          ),
          logoAsset: 'assets/logos/99/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/99/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/99/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  // M-Chai Sacco configuration (Client ID: 90)
  static void _registerMchaiClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '90',
        ClientConfig(
          clientId: '90',
          displayName: 'M-Chai',
          colors: ClientColorPalette(
            primary: Color(0xFF367844),
            secondary: Color(0xFF7ad836),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87),
            unselectedNavItem: Color(0xFF234e87),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/90/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/90/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/90/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // Mchipuka Sacco configuration (Client ID: 85)
  static void _registerMchipukaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
      '85',
      ClientConfig(
        clientId: '85',
        displayName: 'M-chipuka Sacco',
        colors: ClientColorPalette(
          primary: Color(0xFF171D2E),
          secondary: Color(0xFF333987),
          background: Color(0xFFF5F5F5),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFD32F2F),
          success: Color(0xFF0E7228),
          warning: Color(0xFFFFA000),
          info: Color(0xFF1976D2),
          textPrimary: Color(0xFF212121),
          textSecondary: Color(0xFF757575),
          textDisabled: Color(0xFFBDBDBD),
          modalBackground: Color(0xFF2C2F73),
          unselectedNavItem: Color(0xFF2C2F73),
          fontColor: Color(0xFF000000),
          accountCardColor:Color(0xFF171D2E),
        ),
        logoAsset: 'assets/logos/85/logo.png',
        fontFamily: FontHelper.poppinsFontFamily,
        splashConfig: SplashScreenConfig(
          type: "image",
          assetPath: 'assets/images/85/splash.png',
          duration: const Duration(seconds: 3),
          fallbackImagePath: 'assets/logos/85/logo.png',
        ),
        appIdleTimeout: 120000,
        showAtmLocator: false,
        showLoanCalculator: false,
        showScanToPay: true,
      ),
    );
  }

  // M-BORESHA configuration (Client ID: 93)
  static void _registerMBoreshaClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '93',
        ClientConfig(
          clientId: '93',
          displayName: 'M-BORESHA',
          colors: ClientColorPalette(
            secondary: Color(0xFFC6A262), // Primary color #388515
            primary: Color(0xFF008000), // Secondary color #B1D848
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/93/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/93/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/93/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerEgertonClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '60',
        ClientConfig(
          clientId: '60',
          displayName: 'Egerton Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF077833), // Primary color #388515
            primary: Color(0xFFFF4915), // Secondary color #B1D848
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFFee811e),
          ),
          logoAsset: 'assets/logos/60/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/60/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/60/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerQwetuClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '78',
        ClientConfig(
          clientId: '78',
          displayName: 'Qwetu Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFFfde428),
            secondary: Color(0xFF154734),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/78/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/78/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/78/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerNafasiClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '106',
        ClientConfig(
          clientId: '106',
          displayName: 'Nafasi Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF9ACD32),
            primary: Color(0xFF008037),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF008000),
            accountCardColors: [
                  Color(0xFF9ACD32),
                  Color(0xFF008037),
            ],
          ),
          logoAsset: 'assets/logos/106/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/106/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/106/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
          showMemberRegistration: true,
        ));
  }

  // Gdc Sacco configuration (Client ID: 77)
  static void _registerGdcClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '77',
        ClientConfig(
          clientId: '77',
          displayName: 'Gdc Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF1975B6),
            primary: Color(0xFF1374B9),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/77/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/77/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/77/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerKencreamClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '108',
        ClientConfig(
          clientId: '108',
          displayName: 'Kencream Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF0C3C86),
            primary: Color(0xFF0C3C86),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/108/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/108/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/108/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerThamaniClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '97',
        ClientConfig(
          clientId: '97',
          displayName: 'Thamani Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF006B3F),
            primary: Color(0xFF000000),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/97/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/97/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/97/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  static void _registerJogooClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '105',
        ClientConfig(
          clientId: '105',
          displayName: 'Jogoo Sacco',
          colors: ClientColorPalette(
            secondary: Color(0xFF28C854),
            primary: Color(0xFF28C854),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF234e87), // Consistent modal background
            unselectedNavItem: Color(0xFF234e87), // Consistent unselected nav
            fontColor: Color(0xFF008000),
            accountCardColor: Color(0xFF008000),
          ),
          logoAsset: 'assets/logos/105/logo.png',
          fontFamily: FontHelper.poppinsFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/105/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/105/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // Ollin Sacco configuration (Client ID: 54)
  static void _registerOllinClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '54',
        ClientConfig(
          clientId: '54',
          displayName: 'Ollin Sacco',
          colors: ClientColorPalette(
            // primary: Color(0xFFFF5A00),orange
            secondary: Color(0xFFF58220),
            primary: Color(0xFF00AEEF),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFFF58220), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/54/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/54/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/54/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  // Tai Sacco configuration (Client ID: 52)
  static void _registerTaiClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '52',
        ClientConfig(
          clientId: '52',
          displayName: 'Tai Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFF247945),
            secondary: Color(0xFFA4C73E),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF00874D), // Use primary color
            unselectedNavItem: Color(0xFF6B4779),
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/52/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/52/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/52/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: true,
        ));
  }

  static void _registerBandariClient(ClientThemeManager manager) {
    manager.registerClientConfig(
        '89',
        ClientConfig(
          clientId: '89',
          displayName: 'Bandari Sacco',
          colors: ClientColorPalette(
            primary: Color(0xFFFFD700),
            secondary: Color(0xFF0066B3),
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF0066B3), // Use primary color
            unselectedNavItem: Color(0xFF0066B3),
            fontColor: Color(0xFF000000),
            accountCardColors: [
              Color(0xFF0066B3),
              Color(0xFFFFD700)
            ],
          ),
          logoAsset: 'assets/logos/89/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/89/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/89/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }

  // Register a dynamic client based on CLIENT_ID
  static void registerDynamicClient(String clientId) {
    final manager = ClientThemeManager();

    // Skip if already registered
    if (manager.hasClient(clientId)) {
      return;
    }

    // Create a dynamic configuration
    manager.registerClientConfig(
        clientId,
        ClientConfig(
          clientId: clientId,
          displayName: 'Client $clientId',
          colors: ClientColorPalette(
            primary: Color(0xFF6B4E71), // Default purple
            secondary: Color(0xFF8A6B8F), // Default secondary
            background: Color(0xFFF5F5F5),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            success: Color(0xFF43A047),
            warning: Color(0xFFFFA000),
            info: Color(0xFF1976D2),
            textPrimary: Color(0xFF212121),
            textSecondary: Color(0xFF757575),
            textDisabled: Color(0xFFBDBDBD),
            modalBackground: Color(0xFF6B4779), // Consistent modal background
            unselectedNavItem: Color(0xFF6B4779), // Consistent unselected nav
            fontColor: Color(0xFF000000),
          ),
          logoAsset: 'assets/logos/$clientId/logo.png',
          fontFamily: FontHelper.interFontFamily,
          splashConfig: SplashScreenConfig(
            type: "image",
            assetPath: 'assets/images/$clientId/splash.png',
            duration: const Duration(seconds: 3),
            fallbackImagePath: 'assets/logos/logo.png',
          ),
          appIdleTimeout: 120000,
          showAtmLocator: false,
          showLoanCalculator: false,
          showScanToPay: false,
        ));
  }
}