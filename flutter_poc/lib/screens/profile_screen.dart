import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_config.dart';
import '../providers/theme_provider.dart';

/// Profile + settings screen.
/// Includes a "Compiled Theme Info" tile so you can verify
/// which client config was applied at runtime.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ThemeProvider>().config;
    final colors = config.colors;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 32),
            // ── Avatar & name ────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colors.primary.withOpacity(0.15),
                    child: Text(
                      'CN',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Candice Ngundo',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '+254 712 345 678',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Account settings ─────────────────────────────────────────
            _SectionHeader(title: 'Account'),
            _SettingsTile(icon: Icons.person_outline, label: 'Edit Profile', primaryColor: colors.primary),
            _SettingsTile(icon: Icons.lock_outline, label: 'Change PIN', primaryColor: colors.primary),
            _SettingsTile(
              icon: Icons.fingerprint,
              label: 'Biometric Authentication',
              primaryColor: colors.primary,
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: colors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // ── Preferences ──────────────────────────────────────────────
            _SectionHeader(title: 'Preferences'),
            _SettingsTile(icon: Icons.notifications_outlined, label: 'Notifications', primaryColor: colors.primary),
            _SettingsTile(icon: Icons.palette_outlined, label: 'Theme', primaryColor: colors.primary),
            const SizedBox(height: 12),

            // ── Support ──────────────────────────────────────────────────
            _SectionHeader(title: 'Support'),
            _SettingsTile(icon: Icons.phone_outlined, label: 'Call Support', primaryColor: colors.primary),
            _SettingsTile(icon: Icons.email_outlined, label: 'Email Support', primaryColor: colors.primary),
            _SettingsTile(icon: Icons.help_outline, label: 'FAQ', primaryColor: colors.primary),
            const SizedBox(height: 20),

            // ── Compiled theme metadata ───────────────────────────────────
            _ThemeMetadataTile(config: config),
            const SizedBox(height: 16),

            // ── Logout ───────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => context.read<ThemeProvider>().onLogout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primaryColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.primaryColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {},
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ── Theme metadata tile ────────────────────────────────────────────────────────

/// Shows the compiled theme configuration — useful for verifying that the
/// API-driven compilation worked correctly.
class _ThemeMetadataTile extends StatelessWidget {
  final AppThemeConfig config;

  const _ThemeMetadataTile({required this.config});

  String _colorHex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                'Compiled Theme',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetaRow(label: 'Client ID', value: config.clientId),
          _MetaRow(label: 'App Name', value: config.displayName),
          _MetaRow(label: 'Font Family', value: config.fontFamily),
          _MetaRow(label: 'Primary', value: _colorHex(config.colors.primary)),
          _MetaRow(label: 'Secondary', value: _colorHex(config.colors.secondary)),
          _MetaRow(label: 'Dark Mode', value: config.darkMode ? 'Yes' : 'No'),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
