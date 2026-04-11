import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';

/// Shell screen that hosts the bottom tab navigator.
/// Mirrors the tab-switching logic in App.tsx from kijani-finance.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    PaymentsScreen(),
    _TransactionsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TransactionsScreen extends StatelessWidget {
  const _TransactionsScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Transaction History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Full history coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
