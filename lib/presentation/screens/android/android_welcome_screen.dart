import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Android logged-out entry (canvas: "Welcome v2 (swipe slides)"): brand
/// header, three swipeable slides (live map, friends, badges) with dots,
/// then Google / email sign-up and "Look around first" / "I have an account".
class AndroidWelcomeScreen extends StatefulWidget {
  const AndroidWelcomeScreen({super.key});

  @override
  State<AndroidWelcomeScreen> createState() => _AndroidWelcomeScreenState();
}

class _AndroidWelcomeScreenState extends State<AndroidWelcomeScreen> {
  static const _slides = 3;
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    void push(Widget screen) =>
        Navigator.of(context).push(PageTransitions.fade(screen));
    final copy = [
      (l10n.welcomeTitle, l10n.welcomeSlideLiveBody),
      (l10n.welcomeSlideFriendsTitle, l10n.welcomeSlideFriendsBody),
      (l10n.welcomeSlideBadgesTitle, l10n.welcomeSlideBadgesBody),
    ];

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                    child: Row(children: [
                      const WandererLogo(size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Wanderer',
                            style: WandererTheme.display(20, color: c.text)),
                      ),
                      const AndroidLanguageChip(),
                    ]),
                  ),
                ),
                // Slides keep the canvas size (380dp art + copy, the art gives way first) and the dots
                // sit right under the copy; spare height goes below them.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Column(children: [
                      SizedBox(
                        height: math.max(0, math.min(box.maxHeight - 36, 530)),
                        child: PageView.builder(
                          key: const Key('welcome_slides'),
                          controller: _pages,
                          itemCount: _slides,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (context, i) => _Slide(
                            index: i,
                            title: copy[i].$1,
                            body: copy[i].$2,
                            onTapArt: () => _go((i + 1) % _slides),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(children: [
                          for (var i = 0; i < _slides; i++)
                            Semantics(
                              button: true,
                              selected: i == _index,
                              label: l10n.welcomeSlideN(i + 1),
                              child: GestureDetector(
                                onTap: () => _go(i),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: i == _index ? 24 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i == _index ? c.text : c.line,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AndroidGoogleButton(
                        key: const Key('welcome_google'),
                        label: l10n.continueWithGoogle,
                        onPressed: () =>
                            push(const AuthScreen(autoStartSso: true)),
                      ),
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: const Key('welcome_signup'),
                        child: androidPrimaryButton(
                          l10n.welcomeSignUpEmail,
                          onPressed: () =>
                              push(const AuthScreen(startInSignup: true)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: TextButton(
                              key: const Key('welcome_guest'),
                              onPressed: () => push(const AndroidExploreTab()),
                              style: TextButton.styleFrom(
                                  foregroundColor: c.textMuted,
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              child: Text(l10n.welcomeLookAround,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Flexible(
                            child: TextButton(
                              key: const Key('welcome_login'),
                              onPressed: () => push(const AuthScreen()),
                              style: TextButton.styleFrom(
                                  foregroundColor: c.accentText,
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              child: Text(l10n.welcomeHaveAccount,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One slide: artwork card (tap for the next slide) over its title and body.
/// The card gives up its room first on short screens or large text.
class _Slide extends StatelessWidget {
  final int index;
  final String title;
  final String body;
  final VoidCallback onTapArt;
  const _Slide(
      {required this.index,
      required this.title,
      required this.body,
      required this.onTapArt});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return LayoutBuilder(builder: (context, box) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
      final showArt = box.maxHeight >= 360 && !largeText;
      final text = Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title,
                  style: WandererTheme.display(30, color: c.text)
                      .copyWith(height: 1.1, letterSpacing: -0.6)),
            ),
            const SizedBox(height: 8),
            Text(body,
                style:
                    TextStyle(fontSize: 15, height: 1.5, color: c.textMuted)),
          ],
        ),
      );
      if (!showArt) {
        return SingleChildScrollView(
            physics: const ClampingScrollPhysics(), child: text);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: GestureDetector(
                  onTap: onTapArt,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: ExcludeSemantics(
                      child: switch (index) {
                        0 => const _LiveArt(),
                        1 => const _FriendsArt(),
                        _ => const _BadgesArt(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          text,
        ],
      );
    });
  }
}

/// Slide 1: route drawing itself over a map with update markers and a
/// "Live · Day 12" chip.
class _LiveArt extends StatelessWidget {
  const _LiveArt();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _MapPainter(c, route: true)),
      Positioned(
        left: 16,
        right: 70,
        bottom: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x241B1A17),
                  blurRadius: 20,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c.skyFg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.welcomeArtLive,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.skyFg)),
                  Text(l10n.welcomeArtCheckedIn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                ],
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Slide 2: a stack of the notifications friends get.
class _FriendsArt extends StatelessWidget {
  const _FriendsArt();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final toasts = [
      (
        Icons.chat_bubble_outline,
        c.trailSoftBg,
        c.trailSoftFg,
        l10n.welcomeArtCommentTitle,
        l10n.welcomeArtCommentBody
      ),
      (
        Icons.place_outlined,
        c.skyBg,
        c.skyFg,
        l10n.welcomeArtCheckInTitle,
        l10n.welcomeArtCheckInBody
      ),
      (
        Icons.person_add_alt_outlined,
        c.forestBg,
        c.forestFg,
        l10n.welcomeArtFollowTitle,
        l10n.welcomeArtFollowBody
      ),
    ];
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _MapPainter(c, route: false)),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
        child: Column(children: [
          for (final (icon, bg, fg, title, body) in toasts)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1A1B1A17),
                          blurRadius: 16,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 20, color: fg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.text)),
                          Text(body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 13, color: c.textMuted)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Slide 3: a 3×2 badge grid, five unlocked and the next one locked.
class _BadgesArt extends StatelessWidget {
  const _BadgesArt();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final badges = [
      l10n.welcomeArtFirstTrip,
      l10n.achievementKm(100),
      l10n.achievementDays(45),
      l10n.achievementKm(1000),
      l10n.achievementUpdatesCount(100),
    ];
    Widget badge(String label, String sub, {bool locked = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: locked ? c.surface : c.goldBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: locked ? c.line : c.goldFg.withValues(alpha: 0.25)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: locked ? c.raised : const Color(0xFFF5B83D),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    locked ? Icons.lock_outline : Icons.emoji_events_outlined,
                    size: 24,
                    color: locked ? c.caption : const Color(0xFF5B3A00)),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              Text(sub, style: TextStyle(fontSize: 12, color: c.caption)),
            ]),
          ),
        );
    return Container(
      color: c.trailSoftBg,
      padding: const EdgeInsets.all(22),
      child: Column(children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Expanded(
            child: Row(children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 10),
                Expanded(
                  child: row * 3 + col < badges.length
                      ? badge(badges[row * 3 + col], l10n.welcomeArtUnlocked)
                      : badge(l10n.achievementKm(2200),
                          l10n.homeToGo(l10n.achievementKm(85)),
                          locked: true),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Canvas map backdrop (380×380): land, water, two roads; with [route] the
/// orange trail, check-in dots, start / night / day markers and the live dot.
class _MapPainter extends CustomPainter {
  final WandererColors c;
  final bool route;
  const _MapPainter(this.c, {required this.route});

  @override
  void paint(Canvas canvas, Size size) {
    // Cover: scale to the longer side and centre.
    final s = size.width > size.height ? size.width / 380 : size.height / 380;
    canvas.translate((size.width - 380 * s) / 2, (size.height - 380 * s) / 2);
    canvas.scale(s);
    Paint fill(Color color) => Paint()..color = color;
    Paint stroke(Color color, double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 380, 380), fill(c.mapGround));
    canvas.drawPath(
      Path()
        ..moveTo(0, 280)
        ..cubicTo(70, 260, 130, 300, 200, 290)
        ..cubicTo(270, 280, 320, 250, 380, 270)
        ..lineTo(380, 380)
        ..lineTo(0, 380)
        ..close(),
      fill(c.skyBg),
    );
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(290, 110), width: 140, height: 64),
        fill(c.forestBg));
    canvas.drawPath(
        Path()
          ..moveTo(0, 150)
          ..cubicTo(120, 130, 220, 180, 380, 150),
        stroke(c.line, 7));
    canvas.drawPath(
        Path()
          ..moveTo(120, 0)
          ..cubicTo(140, 120, 110, 240, 150, 380),
        stroke(c.line, 5));

    final trail = stroke(WandererTheme.trail, 5);
    if (!route) {
      canvas.drawPath(
          Path()
            ..moveTo(60, 330)
            ..cubicTo(120, 280, 180, 250, 230, 200)
            ..cubicTo(280, 150, 300, 120, 330, 80),
          trail..color = WandererTheme.trail.withValues(alpha: 0.5));
      return;
    }
    canvas.drawPath(
        Path()
          ..moveTo(70, 320)
          ..cubicTo(110, 280, 120, 240, 160, 220)
          ..cubicTo(200, 200, 230, 200, 250, 160)
          ..cubicTo(270, 120, 300, 90, 320, 70),
        trail);
    final white = stroke(Colors.white, 3);
    for (final o in const [Offset(205, 205), Offset(245, 168)]) {
      canvas.drawCircle(o, 6, fill(Colors.white));
      canvas.drawCircle(o, 6, stroke(c.skyFg, 3));
    }
    for (final (o, color) in [
      (const Offset(70, 320), const Color(0xFF2F6B4F)),
      (const Offset(160, 222), const Color(0xFF5B4B8A)),
      (const Offset(178, 214), const Color(0xFFD19A12)),
    ]) {
      canvas.drawCircle(o, 15, fill(color));
      canvas.drawCircle(o, 15, white);
    }
    canvas.drawCircle(const Offset(320, 70), 26,
        fill(const Color(0xFF2F5C8A).withValues(alpha: 0.18)));
    canvas.drawCircle(const Offset(320, 70), 10, fill(const Color(0xFF2F5C8A)));
    canvas.drawCircle(const Offset(320, 70), 10, white);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.c != c || old.route != route;
}
