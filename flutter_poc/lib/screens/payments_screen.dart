import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/theme_config.dart';
import '../providers/theme_provider.dart';

/// Payments screen — mirrors Payments.tsx from kijani-finance.
/// Implements the multi-step flow: services → form → confirm → success.
/// Available services are driven by [AppFeatureFlags] from the compiled theme.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

enum _PayStep { services, form, confirm, success }

class _PaymentsScreenState extends State<PaymentsScreen> {
  _PayStep _step = _PayStep.services;
  String? _activeService;

  void _selectService(String id) =>
      setState(() { _activeService = id; _step = _PayStep.form; });

  void _goBack() => setState(() {
        _step = _step == _PayStep.form ? _PayStep.services : _PayStep.form;
      });

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ThemeProvider>().config;
    final colors = config.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // ── Dynamic header ─────────────────────────────────────────
              if (_step == _PayStep.services) ...[
                const Text(
                  'Payments',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Send money and pay bills easily',
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ] else if (_step == _PayStep.success) ...[
                const Text(
                  'Payment',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ] else ...[
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _serviceLabel(_activeService),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // ── Step content ───────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (_step) {
                    _PayStep.services => _ServicesView(
                        key: const ValueKey('services'),
                        features: config.features,
                        onSelect: _selectService,
                      ),
                    _PayStep.form => _PaymentForm(
                        key: const ValueKey('form'),
                        service: _activeService!,
                        primaryColor: colors.primary,
                        onContinue: () =>
                            setState(() => _step = _PayStep.confirm),
                      ),
                    _PayStep.confirm => _ConfirmView(
                        key: const ValueKey('confirm'),
                        primaryColor: colors.primary,
                        onBack: _goBack,
                        onConfirm: () =>
                            setState(() => _step = _PayStep.success),
                      ),
                    _PayStep.success => _SuccessView(
                        key: const ValueKey('success'),
                        primaryColor: colors.primary,
                        onDone: () =>
                            setState(() => _step = _PayStep.services),
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _serviceLabel(String? id) {
    switch (id) {
      case 'send': return 'Send Money';
      case 'paybill': return 'Paybill';
      case 'till': return 'Buy Goods';
      case 'airtime': return 'Airtime';
      default: return '';
    }
  }
}

// ── Services list ──────────────────────────────────────────────────────────────

class _Service {
  final String id;
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _Service({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}

class _ServicesView extends StatelessWidget {
  final AppFeatureFlags features;
  final void Function(String) onSelect;

  const _ServicesView({super.key, required this.features, required this.onSelect});

  List<_Service> _buildServices() {
    return [
      if (features.sendMoney)
        const _Service(
          id: 'send',
          icon: Icons.send_rounded,
          label: 'Send Money',
          description: 'To any phone number',
          color: Color(0xFF3B82F6),
        ),
      if (features.paybill)
        const _Service(
          id: 'paybill',
          icon: Icons.business_rounded,
          label: 'Paybill',
          description: 'Utilities, business, etc.',
          color: Color(0xFFF59E0B),
        ),
      if (features.buyGoods)
        const _Service(
          id: 'till',
          icon: Icons.storefront_rounded,
          label: 'Buy Goods',
          description: 'Pay at a shop / till',
          color: Color(0xFF22C55E),
        ),
      if (features.airtime)
        const _Service(
          id: 'airtime',
          icon: Icons.smartphone_rounded,
          label: 'Airtime',
          description: 'Safaricom, Airtel, Telkom',
          color: Color(0xFFA855F7),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final services = _buildServices();
    return ListView(
      children: services.asMap().entries.map((e) {
        final s = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ServiceTile(service: s, onTap: () => onSelect(s.id))
              .animate()
              .fadeIn(delay: (e.key * 80).ms, duration: 350.ms)
              .slideY(begin: 0.1),
        );
      }).toList(),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _Service service;
  final VoidCallback onTap;

  const _ServiceTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: service.color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(service.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    service.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ── Payment form ───────────────────────────────────────────────────────────────

class _PaymentForm extends StatelessWidget {
  final String service;
  final Color primaryColor;
  final VoidCallback onContinue;

  const _PaymentForm({
    super.key,
    required this.service,
    required this.primaryColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildFields(service),
                const SizedBox(height: 18),
                const Text(
                  'Amount (KES)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const TextField(
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(hintText: '0.00'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFields(String svc) {
    switch (svc) {
      case 'send':
        return [
          const Text('Recipient Phone Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.smartphone_outlined),
              hintText: '0712 345 678',
            ),
          ),
        ];
      case 'paybill':
        return [
          const Text('Paybill Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'e.g. 888888')),
          const SizedBox(height: 16),
          const Text('Account Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const TextField(decoration: InputDecoration(hintText: 'e.g. 12345678')),
        ];
      case 'till':
        return [
          const Text('Till Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'e.g. 123456')),
        ];
      case 'airtime':
        return [
          const Text('Phone Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(hintText: '0712 345 678')),
        ];
      default:
        return [];
    }
  }
}

// ── Confirm view ───────────────────────────────────────────────────────────────

class _ConfirmView extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const _ConfirmView({
    super.key,
    required this.primaryColor,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Confirm Payment',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Please review the details below',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _Row(label: 'Recipient', value: 'John Doe (+254 712 345 678)'),
                _Row(label: 'Amount', value: 'KES 2,500.00'),
                _Row(label: 'Transaction Fee', value: 'KES 35.00'),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('KES 2,535.00',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: primaryColor)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ensure recipient details are correct. Transactions cannot be reversed easily.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBack,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        child: const Text('Confirm & Pay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success view ───────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onDone;

  const _SuccessView({super.key, required this.primaryColor, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 6),
              const Text(
                'Ref: KJN-88293-XPL',
                style: TextStyle(color: Colors.grey),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'AMOUNT PAID',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES 2,535.00',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Share Receipt'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onDone,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
            ],
          ),
        ],
      ),
    );
  }
}
