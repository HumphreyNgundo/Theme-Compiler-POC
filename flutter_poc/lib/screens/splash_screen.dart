import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/theme_compiler_service.dart';

/// The first screen the user sees.
///
/// Triggers [ThemeProvider.compileTheme] which streams compilation progress
/// through [ThemeCompilerService]. Each step is rendered as a console-style
/// log line, mirroring the way a build system reports its pipeline stages.
///
/// Once compilation is done the provider transitions to [AppState.login].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the compile pipeline after the first frame so the splash UI
    // is rendered before the async work starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThemeProvider>().compileTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        final bg = provider.config.splashConfig.backgroundColor;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _AppLogo(
                    name: provider.config.displayName,
                    tagline: provider.config.tagline,
                  ),
                  const Spacer(flex: 3),
                  _CompilerConsole(steps: provider.compileSteps),
                  const SizedBox(height: 20),
                  _ProgressBar(progress: provider.compileProgress),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── App logo + name ────────────────────────────────────────────────────────────

class _AppLogo extends StatelessWidget {
  final String name;
  final String tagline;

  const _AppLogo({required this.name, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 46,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 18),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 6),
        Text(
          tagline,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 14,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
      ],
    );
  }
}

// ── Compiler console ───────────────────────────────────────────────────────────

class _CompilerConsole extends StatelessWidget {
  final List<CompileStep> steps;

  const _CompilerConsole({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                color: Colors.white.withOpacity(0.45),
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'theme_compiler_service.dart',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map((s) => _StepRow(step: s)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

class _StepRow extends StatelessWidget {
  final CompileStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: step.isComplete
                ? const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 14)
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 200.ms,
                    )
                : step.isActive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.white.withOpacity(0.2),
                        size: 12,
                      ),
          ),
          const SizedBox(width: 10),
          Text(
            step.label,
            style: TextStyle(
              color: step.isComplete
                  ? Colors.white.withOpacity(0.6)
                  : step.isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.25),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight:
                  step.isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ───────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
