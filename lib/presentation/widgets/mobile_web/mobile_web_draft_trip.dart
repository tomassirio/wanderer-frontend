import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/app_handoff.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';

class MobileWebDraftTrip extends StatelessWidget {
  final TripDetailLayoutData data;
  const MobileWebDraftTrip({super.key, required this.data});

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(
          ClipboardData(text: ApiEndpoints.tripDeepLink(data.trip.id)));
      if (context.mounted) {
        UiHelpers.showSuccessMessage(
            context, context.l10n.dialogsShareLinkCopied);
      }
    } catch (e) {
      if (context.mounted) UiHelpers.showErrorMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final trip = data.trip;
    final visibility = switch (trip.visibility) {
      Visibility.public => l10n.newTripPublic,
      Visibility.protected => l10n.newTripFriends,
      Visibility.private => l10n.newTripPrivate,
    };
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        backgroundColor: c.ground,
        leading: BackButton(onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          }
        }),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'delete') {
                data.onDeleteTrip?.call();
              } else {
                TripShareDialog.show(context,
                    tripId: trip.id, tripName: trip.name, compact: true);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'share', child: Text(l10n.shareTrip)),
              if (data.onDeleteTrip != null)
                PopupMenuItem(
                    value: 'delete', child: Text(l10n.tripDetailDeleteTitle)),
            ],
          ),
        ],
      ),
      bottomNavigationBar:
          AndroidShell.navigationBar(context, AndroidTab.trips),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Wrap(spacing: 6, children: [
              Pill.status(context, trip.status),
              Pill(visibility)
            ]),
            const SizedBox(height: 12),
            Text(trip.name, style: WandererTheme.display(28, color: c.text)),
            const SizedBox(height: 6),
            Text(
                l10n.draftTripCreated(
                    DateFormatHelper.formatRelativeDate(l10n, trip.createdAt)),
                style: TextStyle(fontSize: 14, color: c.caption)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: WandererTheme.cardDecoration(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Pill(l10n.draftTripNextStep,
                            tone: PillTone.promoted)),
                    const SizedBox(height: 16),
                    Text(l10n.mobileWebStartApp,
                        style: WandererTheme.display(23, color: c.text)),
                    const SizedBox(height: 14),
                    Text(l10n.mobileWebDraftBody,
                        style: TextStyle(
                            fontSize: 15, height: 1.5, color: c.textMuted)),
                    const SizedBox(height: 16),
                    const MobileWebPlayButton(),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () =>
                            AndroidAppLinks.open(context, tripId: trip.id),
                        child: Text(l10n.mobileWebOpenTrip,
                            textAlign: TextAlign.center)),
                  ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: WandererTheme.cardDecoration(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.tripSettings,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: Text(l10n.visibility,
                              style: TextStyle(color: c.caption))),
                      PopupMenuButton<Visibility>(
                        initialValue: trip.visibility,
                        onSelected: data.onVisibilityChange,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: Visibility.public,
                              child: Text(l10n.newTripPublic)),
                          PopupMenuItem(
                              value: Visibility.protected,
                              child: Text(l10n.newTripFriends)),
                          PopupMenuItem(
                              value: Visibility.private,
                              child: Text(l10n.newTripPrivate)),
                        ],
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(visibility,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: c.text))),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                          child: Text(l10n.newTripAutoCheckIn,
                              style: TextStyle(color: c.caption))),
                      Text(
                          trip.automaticUpdates
                              ? l10n.newTripMinutes(
                                  (trip.effectiveUpdateRefresh / 60).round())
                              : l10n.dialogsFromPlanAutoOff,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: c.text)),
                    ]),
                  ]),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: () => _copy(context),
                child: Text(l10n.dialogsShareCopyLink)),
          ]),
    );
  }
}
