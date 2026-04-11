import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_definition.dart';
import '../providers/engine_provider.dart';
import 'icon_resolver.dart';

// ---------------------------------------------------------------------------
// Action callback type
// ---------------------------------------------------------------------------

typedef OnAction = void Function(ActionDef action);

// ---------------------------------------------------------------------------
// ComponentRegistry
//
// Maps every component type string from the JSON to a Flutter widget builder.
// This is the heart of the engine: adding a new component type here makes it
// available in every screen definition without touching any screen code.
// ---------------------------------------------------------------------------

class ComponentRegistry {
  ComponentRegistry._();

  /// Build a widget from a [ComponentDef]. Returns an error tile for unknown types.
  static Widget build({
    required ComponentDef def,
    required ThemeDef theme,
    required AppDefinition appDef,
    required OnAction onAction,
    Map<String, dynamic> formState = const {},
  }) {
    final ctx = _BuildCtx(
      theme: theme,
      appDef: appDef,
      onAction: onAction,
      formState: formState,
    );
    return ctx.build(def);
  }
}

// ---------------------------------------------------------------------------
// Internal build context — threaded through recursive builds
// ---------------------------------------------------------------------------

class _BuildCtx {
  final ThemeDef theme;
  final AppDefinition appDef;
  final OnAction onAction;
  final Map<String, dynamic> formState;

  const _BuildCtx({
    required this.theme,
    required this.appDef,
    required this.onAction,
    required this.formState,
  });

  // ── Entry point ───────────────────────────────────────────────────────────

  Widget build(ComponentDef def) {
    try {
      return _dispatch(def);
    } catch (e) {
      return _error(def.type, e.toString());
    }
  }

  List<Widget> buildAll(List<ComponentDef> defs) =>
      defs.map(build).toList();

  // ── Dispatcher ────────────────────────────────────────────────────────────

  Widget _dispatch(ComponentDef d) {
    switch (d.type) {
      // Layout
      case 'scroll_view':    return _scrollView(d);
      case 'list_view':      return _listView(d);
      case 'column':         return _column(d);
      case 'row':            return _row(d);
      case 'center':         return _center(d);
      case 'card':           return _card(d);
      case 'spacer':         return _spacer(d);
      case 'divider':        return const Divider(height: 1);

      // Text
      case 'text':           return _text(d);
      case 'field_label':    return _fieldLabel(d);
      case 'section_label':  return _sectionLabel(d);
      case 'detail_row':     return _detailRow(d);

      // Inputs
      case 'text_field':     return _textField(d);
      case 'form':           return _form(d);

      // Buttons
      case 'button':         return _button(d);
      case 'outlined_button':return _outlinedButton(d);
      case 'biometric_button': return _biometricButton(d);

      // Compound / domain
      case 'icon_box':            return _iconBox(d);
      case 'dashboard_header':    return _dashboardHeader(d);
      case 'account_carousel':    return _accountCarousel(d);
      case 'quick_action_grid':   return _quickActionGrid(d);
      case 'transaction_list':    return _transactionList(d);
      case 'service_tile':        return _serviceTile(d);
      case 'section':             return _section(d);
      case 'avatar':              return _avatar(d);
      case 'settings_tile':       return _settingsTile(d);
      case 'warning_box':         return _warningBox(d);
      case 'success_view':        return _successView(d);
      case 'engine_info_card':    return _engineInfoCard(d);

      default:
        return _error(d.type, 'Unregistered component type');
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  Widget _scrollView(ComponentDef d) {
    final padding = d.propOr<num>('padding', 0).toDouble();
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buildAll(d.children ?? []),
      ),
    );
  }

  Widget _listView(ComponentDef d) {
    final padding = d.propOr<num>('padding', 0).toDouble();
    return ListView(
      padding: EdgeInsets.all(padding),
      children: buildAll(d.children ?? []),
    );
  }

  Widget _column(ComponentDef d) {
    final pad = d.propOr<num>('padding', 0).toDouble();
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buildAll(d.children ?? []),
      ),
    );
  }

  Widget _row(ComponentDef d) {
    final children = d.children ?? [];
    return Row(
      children: children.map((c) {
        final flex = c.propOr<int>('flex', 0);
        final w = build(c);
        return flex > 0 ? Expanded(flex: flex, child: w) : w;
      }).toList(),
    );
  }

  Widget _center(ComponentDef d) {
    final children = d.children ?? [];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: buildAll(children),
      ),
    );
  }

  Widget _card(ComponentDef d) {
    final pad = d.propOr<num>('padding', 16).toDouble();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: buildAll(d.children ?? []),
        ),
      ),
    );
  }

  Widget _spacer(ComponentDef d) {
    final h = d.propOr<num>('height', 0).toDouble();
    final w = d.propOr<num>('width', 0).toDouble();
    return SizedBox(height: h > 0 ? h : null, width: w > 0 ? w : null);
  }

  // ── Text ───────────────────────────────────────────────────────────────────

  Widget _text(ComponentDef d) {
    final raw = d.propOr<String>('value', '');
    final value = _resolveString(raw);
    final style = d.prop<String>('style') ?? 'body';
    final weight = d.prop<String>('weight');
    final colorVal = d.prop<String>('color');
    final align = d.prop<String>('align');

    final color = colorVal != null ? theme.resolve(colorVal) : null;
    final fw = weight == 'bold' ? FontWeight.bold : FontWeight.normal;
    final ta = align == 'center' ? TextAlign.center : TextAlign.start;

    TextStyle ts;
    switch (style) {
      case 'headline':
        ts = TextStyle(fontSize: 24, fontWeight: fw, color: color ?? theme.textPrimary);
      case 'title':
        ts = TextStyle(fontSize: 18, fontWeight: fw, color: color ?? theme.textPrimary);
      case 'caption':
        ts = TextStyle(fontSize: 12, color: color ?? theme.textSecondary);
      default:
        ts = TextStyle(fontSize: 14, fontWeight: fw, color: color ?? theme.textPrimary);
    }

    return Text(value, style: ts, textAlign: ta);
  }

  Widget _fieldLabel(ComponentDef d) {
    return Text(
      d.propOr<String>('text', ''),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );
  }

  Widget _sectionLabel(ComponentDef d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        d.propOr<String>('text', '').toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _detailRow(ComponentDef d) {
    final label = d.propOr<String>('label', '');
    final value = d.propOr<String>('value', '');
    final bold = d.propOr<bool>('bold', false);
    final vcRaw = d.prop<String>('valueColor');
    final vc = vcRaw != null ? theme.resolve(vcRaw) : theme.textPrimary;

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
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: vc,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Inputs ─────────────────────────────────────────────────────────────────

  Widget _textField(ComponentDef d) {
    final hint = d.prop<String>('hint');
    final prefix = d.prop<String>('prefix');
    final prefixIconName = d.prop<String>('prefixIcon');
    final obscure = d.propOr<bool>('obscure', false);
    final maxLen = d.prop<int>('maxLength');
    final large = d.propOr<String>('style', '') == 'large';

    return TextField(
      obscureText: obscure,
      maxLength: maxLen,
      keyboardType: _keyboard(d.prop<String>('inputType')),
      style: large
          ? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
          : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        counterText: maxLen != null ? '' : null,
        prefixIcon: prefixIconName != null
            ? Icon(IconResolver.resolve(prefixIconName))
            : null,
      ),
    );
  }

  Widget _form(ComponentDef d) {
    final fields = (d.props['fields'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final submitLabel = d.propOr<String>('submitLabel', 'Submit');
    final onSubmitRaw = d.props['onSubmit'] as Map<String, dynamic>?;
    final onSubmit = onSubmitRaw != null ? ActionDef.fromJson(onSubmitRaw) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...fields.expand((f) {
                  final label = f['label'] as String? ?? '';
                  final hint = f['hint'] as String?;
                  final inputType = f['inputType'] as String?;
                  final prefixIcon = f['prefixIcon'] as String?;
                  final obscure = f['obscure'] as bool? ?? false;
                  final large = (f['style'] as String?) == 'large';

                  return [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: obscure,
                      keyboardType: _keyboard(inputType),
                      style: large
                          ? const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)
                          : null,
                      decoration: InputDecoration(
                        hintText: hint,
                        prefixIcon: prefixIcon != null
                            ? Icon(IconResolver.resolve(prefixIcon))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ];
                }),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onSubmit != null ? () => onAction(onSubmit) : null,
                  child: Text(submitLabel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _button(ComponentDef d) {
    final label = d.propOr<String>('label', '');
    final iconName = d.prop<String>('icon');
    final action = ActionDef.tryParse(d.props['action']);

    return ElevatedButton(
      onPressed: action != null ? () => onAction(action) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (iconName != null) ...[
            const SizedBox(width: 8),
            Icon(IconResolver.resolve(iconName), size: 18),
          ],
        ],
      ),
    );
  }

  Widget _outlinedButton(ComponentDef d) {
    final label = d.propOr<String>('label', '');
    final iconName = d.prop<String>('icon');
    final danger = d.propOr<bool>('danger', false);
    final action = ActionDef.tryParse(d.props['action']);

    return OutlinedButton(
      onPressed: action != null ? () => onAction(action) : null,
      style: danger
          ? OutlinedButton.styleFrom(
              foregroundColor: theme.error,
              side: BorderSide(color: theme.error),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconName != null) ...[
            Icon(IconResolver.resolve(iconName), size: 18),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _biometricButton(ComponentDef d) {
    final action = ActionDef.tryParse(d.props['action']);
    return Center(
      child: OutlinedButton(
        onPressed: action != null ? () => onAction(action) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.all(16),
          shape: const CircleBorder(),
          side: BorderSide(color: theme.primary, width: 1.5),
        ),
        child: Icon(Icons.fingerprint, size: 34, color: theme.primary),
      ),
    );
  }

  // ── Domain components ─────────────────────────────────────────────────────

  Widget _iconBox(ComponentDef d) {
    final size = d.propOr<num>('size', 72).toDouble();
    final iconSize = d.propOr<num>('iconSize', 38).toDouble();
    final iconName = d.propOr<String>('icon', 'wallet');

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.primary,
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(IconResolver.resolve(iconName),
            color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _dashboardHeader(ComponentDef d) {
    final name = d.propOr<String>('name', 'User');
    final initials = d.propOr<String>('initials', 'U');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.primary.withOpacity(0.15),
            child: Text(initials,
                style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good morning,',
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.5)),
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
              onPressed: () {},
              icon:
                  Icon(Icons.search_rounded, color: theme.textSecondary)),
          Stack(
            children: [
              IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.notifications_outlined,
                      color: theme.textSecondary)),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.error,
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

  Widget _accountCarousel(ComponentDef d) {
    // Mock accounts — in production these come from an authenticated API call
    const accounts = [
      {'type': 'Wallet',  'balance': 45250.50, 'number': '0712****89', 'primary': true},
      {'type': 'Savings', 'balance': 125000.00, 'number': '8829****12', 'primary': false},
    ];

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final a = accounts[i];
          final isPrimary = a['primary'] as bool;
          final gradient = isPrimary
              ? [theme.cardStart, theme.cardEnd]
              : [theme.secondary, theme.secondary.withOpacity(0.75)];

          return Container(
            width: 278,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: gradient.first.withOpacity(0.4),
                    blurRadius: 22,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -24,
                  right: -24,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['type']} ACCOUNT',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(a['number'] as String,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontFamily: 'monospace')),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Active',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text('Available Balance',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text('KES ',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _fmtBalance(a['balance'] as double),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickActionGrid(ComponentDef d) {
    final actions = (d.props['actions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          final color = ThemeDef._hex(a['color'] as String? ?? '#94A3B8');
          final iconName = a['icon'] as String? ?? 'circle';
          final label = a['label'] as String? ?? '';
          final action = ActionDef.tryParse(a['action'] as Map<String, dynamic>?);

          return GestureDetector(
            onTap: action != null ? () => onAction(action) : null,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      Icon(IconResolver.resolve(iconName), color: color, size: 26),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _transactionList(ComponentDef d) {
    final limit = d.propOr<int>('limit', 5);

    const txns = [
      {'title': 'Sent to John Doe',         'sub': 'M-Pesa Transfer', 'amount': -2500.0, 'date': 'Today, 10:45 AM',       'ok': true},
      {'title': 'Received from Jane Smith',  'sub': 'Mobile Money',    'amount':  5000.0, 'date': 'Yesterday, 04:20 PM',   'ok': true},
      {'title': 'Kenya Power',               'sub': 'Paybill 888888',  'amount': -1200.0, 'date': 'Apr 08, 2026',          'ok': true},
      {'title': 'Safaricom Airtime',         'sub': 'Self Purchase',   'amount':  -500.0, 'date': 'Apr 07, 2026',          'ok': true},
      {'title': 'Java House',                'sub': 'Till 123456',     'amount':  -850.0, 'date': 'Apr 07, 2026',          'ok': false},
    ];

    final items = txns.take(limit).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: items.map((t) {
          final isNeg = (t['amount'] as double) < 0;
          final isFail = !(t['ok'] as bool);
          final iconColor = isFail
              ? Colors.red
              : isNeg
                  ? Colors.grey.shade600
                  : theme.primary;
          final iconBg = iconColor.withOpacity(0.1);
          final icon = isFail
              ? Icons.error_outline_rounded
              : isNeg
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(t['sub'] as String,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isNeg ? '-' : '+'} KES ${_fmtAmount((t['amount'] as double).abs())}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isFail
                              ? Colors.red
                              : isNeg
                                  ? Colors.grey.shade700
                                  : theme.primary),
                    ),
                    Text(t['date'] as String,
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _serviceTile(ComponentDef d) {
    final icon = d.propOr<String>('icon', 'circle');
    final label = d.propOr<String>('label', '');
    final description = d.propOr<String>('description', '');
    final colorHex = d.propOr<String>('color', '#94A3B8');
    final color = ThemeDef._hex(colorHex);
    final action = ActionDef.tryParse(d.props['action']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: action != null ? () => onAction(action) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(14)),
                child: Icon(IconResolver.resolve(icon),
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(description,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(ComponentDef d) {
    final title = d.propOr<String>('title', '');
    final actionLabel = d.prop<String>('actionLabel');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              if (actionLabel != null)
                TextButton(
                  onPressed: () {},
                  child: Text(actionLabel,
                      style: TextStyle(color: theme.primary, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...buildAll(d.children ?? []),
        ],
      ),
    );
  }

  Widget _avatar(ComponentDef d) {
    final initials = d.propOr<String>('initials', 'U');
    final size = d.propOr<num>('size', 44).toDouble();

    return Center(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.primary.withOpacity(0.15),
        child: Text(
          initials,
          style: TextStyle(
              color: theme.primary,
              fontSize: size * 0.32,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _settingsTile(ComponentDef d) {
    final icon = d.propOr<String>('icon', 'circle');
    final label = d.propOr<String>('label', '');
    final toggle = d.propOr<bool>('toggle', false);
    final value = d.propOr<bool>('value', false);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child:
              Icon(IconResolver.resolve(icon), color: theme.primary, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: toggle
            ? Switch(
                value: value,
                onChanged: (_) {},
                activeColor: theme.primary,
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {},
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _warningBox(ComponentDef d) {
    final text = d.propOr<String>('text', '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _successView(ComponentDef d) {
    final title = d.propOr<String>('title', 'Success!');
    final reference = d.prop<String>('reference') ?? '';
    final amount = d.propOr<String>('amount', '');
    final doneAction = ActionDef.tryParse(d.props['doneAction']);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: theme.primary.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10))
                ],
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 52),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(reference,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('AMOUNT PAID',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(amount,
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: theme.primary)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () {},
                        child: const Text('Share Receipt')),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          doneAction != null ? () => onAction(doneAction) : null,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the engine metadata so developers can verify the compiled definition.
  Widget _engineInfoCard(ComponentDef d) {
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
              Icon(Icons.terminal_rounded,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Engine Runtime Info',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('App', appDef.appName),
          _infoRow('Version', appDef.version),
          _infoRow('Screens', '${appDef.screens.length} compiled'),
          _infoRow('Font', theme.fontFamily),
          _infoRow('Primary',
              '#${theme.primary.value.toRadixString(16).substring(2).toUpperCase()}'),
          _infoRow('Mode', theme.darkMode ? 'Dark' : 'Light'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _resolveString(String value) {
    if (value == r'$appName') return appDef.appName;
    if (value == r'$tagline') return appDef.tagline;
    return value;
  }

  TextInputType _keyboard(String? type) {
    switch (type) {
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'email':
        return TextInputType.emailAddress;
      default:
        return TextInputType.text;
    }
  }

  String _fmtBalance(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtAmount(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Widget _error(String type, String msg) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text('[$type] $msg',
          style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
    );
  }
}
