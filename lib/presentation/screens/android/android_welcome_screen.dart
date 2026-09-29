import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Android logged-out entry (canvas: "Welcome (logged out)"): illustrated
/// hero with the logo, one line of copy, then Google / email sign-up and
/// "Look around first" / "Sign in".
class AndroidWelcomeScreen extends StatelessWidget {
  const AndroidWelcomeScreen({super.key});

  /// Canvas hero is 420dp including the 36dp status bar.
  static const double _heroHeight = 384;

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    void push(Widget screen) =>
        Navigator.of(context).push(PageTransitions.fade(screen));

    return Scaffold(
      backgroundColor: c.ground,
      body: Column(children: [
        SizedBox(
          height: _heroHeight + top,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HeroPainter(
                  dark: Theme.of(context).brightness == Brightness.dark,
                  ground: c.ground,
                ),
              ),
            ),
            Positioned(
              top: top + 12,
              right: 16,
              child: const AndroidLanguageChip(overImage: true),
            ),
            Positioned(
              top: top + 60,
              left: 0,
              right: 0,
              child: const Center(child: WandererLogo(size: 150)),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(children: [
                  Text(
                    l10n.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: WandererTheme.display(32, color: c.text)
                        .copyWith(height: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, height: 1.5, color: c.textMuted),
                  ),
                ]),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AndroidGoogleButton(
                  label: l10n.continueWithGoogle,
                  onPressed: () => push(const AuthScreen(autoStartSso: true)),
                ),
                const SizedBox(height: 10),
                androidPrimaryButton(
                  l10n.welcomeSignUpEmail,
                  onPressed: () => push(const AuthScreen(startInSignup: true)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: () => push(const AndroidExploreTab()),
                        style:
                            TextButton.styleFrom(foregroundColor: c.textMuted),
                        child: Text(l10n.welcomeLookAround,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () => push(const AuthScreen()),
                        style:
                            TextButton.styleFrom(foregroundColor: c.accentText),
                        child:
                            Text(l10n.signIn, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Canvas hero illustration (412×420 artboard): sky, sun, two dune bands,
/// a ground-coloured strip melting into the page and a dashed orange trail
/// ending in a pin dot. Dusk swaps the sand tones for night ones.
class _HeroPainter extends CustomPainter {
  final bool dark;
  final Color ground;
  const _HeroPainter({required this.dark, required this.ground});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 412, size.height / 420);
    Paint fill(Color color) => Paint()..color = color;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 412, 420),
        fill(dark ? const Color(0xFF2E2924) : const Color(0xFFF3E6D2)));
    canvas.drawCircle(const Offset(300, 110), 70,
        fill(dark ? const Color(0xFF4A3918) : const Color(0xFFF7D6A8)));

    canvas.drawPath(
      Path()
        ..moveTo(0, 300)
        ..cubicTo(70, 260, 130, 290, 206, 250)
        ..cubicTo(282, 210, 340, 230, 412, 262)
        ..lineTo(412, 420)
        ..lineTo(0, 420)
        ..close(),
      fill(dark ? const Color(0xFF39332D) : const Color(0xFFE8C99A)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 350)
        ..cubicTo(90, 318, 170, 352, 260, 320)
        ..cubicTo(350, 288, 370, 318, 412, 330)
        ..lineTo(412, 420)
        ..lineTo(0, 420)
        ..close(),
      fill(dark ? const Color(0xFF4A423A) : const Color(0xFFD9A56B)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 395)
        ..cubicTo(100, 372, 220, 400, 412, 380)
        ..lineTo(412, 420)
        ..lineTo(0, 420)
        ..close(),
      fill(ground),
    );

    // Dashed trail: 2-unit dashes every 14 units, round caps.
    final trail = Path()
      ..moveTo(40, 404)
      ..cubicTo(110, 360, 150, 330, 206, 300)
      ..cubicTo(262, 270, 300, 262, 350, 230);
    final dash = Paint()
      ..color = WandererTheme.trail
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final metric in trail.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 2), dash);
      }
    }
    canvas.drawCircle(const Offset(350, 230), 9, fill(WandererTheme.trail));
    canvas.drawCircle(
      const Offset(350, 230),
      9,
      Paint()
        ..color = dark ? const Color(0xFFF6F1EA) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) =>
      old.dark != dark || old.ground != ground;
}
