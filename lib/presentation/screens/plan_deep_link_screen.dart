import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plan_detail_screen.dart';

class PlanDeepLinkScreen extends ConsumerStatefulWidget {
  final String planId;
  const PlanDeepLinkScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDeepLinkScreen> createState() => _PlanDeepLinkScreenState();
}

class _PlanDeepLinkScreenState extends ConsumerState<PlanDeepLinkScreen> {
  bool _loading = true;
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final loggedIn = await ref.read(homeRepositoryProvider).isLoggedIn();
      if (!mounted) return;
      if (!loggedIn) {
        setState(() {
          _loading = false;
          _needsLogin = true;
        });
        return;
      }
      final plan = await ref
          .read(tripPlanServiceProvider)
          .getTripPlanById(widget.planId);
      if (mounted) {
        Navigator.of(context).pushReplacement(PageTransitions.slideFromRight(
            TripPlanDetailScreen(tripPlan: plan)));
      }
    } catch (e) {
      debugPrint('Plan deep link failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _needsLogin = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.tripPlans)),
        body: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          _needsLogin
                              ? context.l10n.pleaseLogInForPlans
                              : context.l10n.errorLoadingTripPlans,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _needsLogin
                            ? () async {
                                await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                        builder: (_) => const AuthScreen(
                                            returnToCaller: true)));
                                if (mounted) _load();
                              }
                            : _load,
                        child: Text(_needsLogin
                            ? context.l10n.logIn
                            : context.l10n.retry),
                      ),
                    ]),
                  )),
      );
}
