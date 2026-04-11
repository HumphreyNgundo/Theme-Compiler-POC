import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/mock_data.dart';
import '../models/theme_config.dart';
import '../providers/theme_provider.dart';
import '../widgets/account_card.dart';
import '../widgets/transaction_item.dart';

/// Home/Dashboard screen — mirrors Dashboard.tsx from kijani-finance.
/// All colours come from the compiled [AppThemeConfig], not hardcoded values.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ThemeProvider>().config;
    final colors = config.colors;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            // ── Header ──────────────────────────────────────────────────
            _Header(colors: colors).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 20),

            // ── Account cards carousel ───────────────────────────────────
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: mockAccounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) => AccountCard(
                  account: mockAccounts[i],
                  isPrimary: i == 0,
                  colors: colors,
                )
                    .animate()
                    .fadeIn(delay: (i * 100).ms, duration: 400.ms)
                    .slideX(begin: 0.15),
              ),
            ),
            const SizedBox(height: 28),

            // ── Quick actions ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Section(
                title: 'Quick Actions',
                actionLabel: 'View All',
                child: _QuickActionsRow(config: config),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),

            // ── Recent transactions ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Section(
                title: 'Recent Activity',
                actionLabel: 'History',
                child: Column(
                  children: mockTransactions.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TransactionItem(
                        transaction: e.value,
                        primaryColor: colors.primary,
                      )
                          .animate()
                          .fadeIn(delay: (e.key * 60 + 300).ms)
                          .slideY(begin: 0.15),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppColorPalette colors;

  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primary.withOpacity(0.15),
            child: Text(
              'CN',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  'Candice Ngundo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search_rounded, color: colors.textSecondary),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.notifications_outlined,
                  color: colors.textSecondary,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final String actionLabel;
  final Widget child;

  const _Section({
    required this.title,
    required this.actionLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                actionLabel,
                style: TextStyle(color: primary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final AppThemeConfig config;

  const _QuickActionsRow({required this.config});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      if (config.features.sendMoney)
        const _QuickAction(
          icon: Icons.send_rounded,
          label: 'Send',
          color: Color(0xFF3B82F6),
        ),
      if (config.features.airtime)
        const _QuickAction(
          icon: Icons.smartphone_rounded,
          label: 'Airtime',
          color: Color(0xFF22C55E),
        ),
      if (config.features.paybill)
        const _QuickAction(
          icon: Icons.flash_on_rounded,
          label: 'Bills',
          color: Color(0xFFF59E0B),
        ),
      const _QuickAction(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        color: Color(0xFF94A3B8),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((a) => _QuickActionButton(action: a)).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(action.icon, color: action.color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
