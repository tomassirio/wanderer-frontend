import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_welcome_artwork.dart';
import 'package:wanderer_frontend/presentation/widgets/landing/landing_hero.dart';

/// Static app entry: secondary copy and artwork yield space to the actions.
class AndroidWelcomeScreen extends StatelessWidget {
  const AndroidWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    void push(Widget screen) =>
        Navigator.of(context).push(PageTransitions.fade(screen));

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LandingBrandHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final showPreview = box.maxHeight >= 420 && !largeText;
                      final showSubtitle = box.maxHeight >= 280 && !largeText;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (showPreview) ...[
                            const Flexible(
                              flex: 5,
                              child: Center(
                                heightFactor: 1,
                                child: AndroidWelcomeArtwork(),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                          Flexible(
                            flex: 4,
                            fit: FlexFit.loose,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: box.maxWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 300),
                                        child: Text(
                                          l10n.welcomeTitle,
                                          textAlign: TextAlign.center,
                                          style: WandererTheme.display(
                                              box.maxHeight < 280 ? 28 : 36,
                                              color: c.text),
                                        ),
                                      ),
                                    ),
                                    if (showSubtitle) ...[
                                      const SizedBox(height: 14),
                                      Text(l10n.welcomeSubtitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: c.textMuted)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('welcome_login'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      backgroundColor: WandererTheme.trail,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => push(const AuthScreen()),
                    child: Text(l10n.logIn, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('welcome_guest'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      foregroundColor: c.text,
                      side: BorderSide(color: c.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => push(const AndroidExploreTab()),
                    child:
                        Text(l10n.welcomeTryGuest, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
