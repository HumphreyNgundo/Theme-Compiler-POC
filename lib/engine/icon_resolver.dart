import 'package:flutter/material.dart';

/// Maps icon name strings (from JSON) to Flutter IconData.
/// Add entries here as new icons are used in screen definitions.
class IconResolver {
  IconResolver._();

  static IconData resolve(String name) {
    return _map[name] ?? Icons.circle_outlined;
  }

  static const _map = <String, IconData>{
    'home': Icons.home_rounded,
    'send': Icons.send_rounded,
    'receipt': Icons.receipt_long_rounded,
    'person': Icons.person_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'lock': Icons.lock_outline,
    'fingerprint': Icons.fingerprint,
    'arrow_forward': Icons.arrow_forward_rounded,
    'smartphone': Icons.smartphone_rounded,
    'business': Icons.business_rounded,
    'storefront': Icons.storefront_rounded,
    'bolt': Icons.flash_on_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'person_outline': Icons.person_outline,
    'lock_outline': Icons.lock_outline,
    'notifications': Icons.notifications_outlined,
    'palette': Icons.palette_outlined,
    'phone': Icons.phone_outlined,
    'email': Icons.email_outlined,
    'help': Icons.help_outline,
    'logout': Icons.logout_rounded,
    'chevron_right': Icons.chevron_right_rounded,
    'check_circle': Icons.check_circle_rounded,
    'warning': Icons.warning_amber_rounded,
    'search': Icons.search_rounded,
    'bell': Icons.notifications_outlined,
    'arrow_up': Icons.arrow_upward_rounded,
    'arrow_down': Icons.arrow_downward_rounded,
    'error': Icons.error_outline_rounded,
    'terminal': Icons.terminal_rounded,
    'info': Icons.info_outline,
  };
}
