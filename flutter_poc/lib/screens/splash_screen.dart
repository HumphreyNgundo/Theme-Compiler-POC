import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/engine_provider.dart';
import '../engine/app_engine.dart';

/// Shown while [AppEngine] streams its compile pipeline.
/// Renders a terminal-style console with per-step icons and a progress bar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start initialization after the first frame so the provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EngineProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EngineProvider>(
      builder: (context, engine, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  // ── Logo / brand ──────────────────────────────────────────
                  _Logo(name: 'Kijani Finance'),
                  const SizedBox(height: 48),
                  // ── Console header ────────────────────────────────────────
                  _ConsoleHeader(progress: engine.progress),
                  const SizedBox(height: 16),
                  // ── Step list ─────────────────────────────────────────────
                  _StepList(steps: engine.steps),
                  const Spacer(flex: 3),
                  // ── Progress bar ──────────────────────────────────────────
                  _ProgressBar(progress: engine.progress),
                  const SizedBox(height: 12),
                  _StatusText(progress: engine.progress),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.terminal_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Engine v1.0',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);
    return Row(
      children: [
        const Text(
          '\$ compiling app bundle',
          style: TextStyle(
            color: Color(0xFF22C55E),
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '$pct%',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps});
  final List<CompileStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) => _StepRow(step: s)).toList(),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final CompileStep step;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    final Color textColor;

    if (step.isComplete) {
      icon = const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 16);
      textColor = const Color(0xFF22C55E);
    } else if (step.isActive) {
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
        ),
      );
      textColor = Colors.white;
    } else {
      icon = const Icon(Icons.circle_outlined, color: Color(0xFF374151), size: 16);
      textColor = const Color(0xFF6B7280);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 16, height: 16, child: icon),
          const SizedBox(width: 12),
          Text(
            step.label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: const Color(0xFF1F2937),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1.0;
    return Text(
      done ? 'Build complete. Launching app...' : 'Building...',
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }
}
