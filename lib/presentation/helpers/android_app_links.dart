import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

abstract final class AndroidAppLinks {
  static const packageName = 'com.tomassirio.wanderer.wanderer_frontend';

  static Uri intentUri({String? tripId, String? planId}) {
    final path = Uri(pathSegments: [
      '',
      if (tripId != null) ...[
        'trip',
        tripId
      ] else if (planId != null) ...[
        'plan',
        planId
      ],
    ]).path;
    return Uri.parse('intent://$path#Intent;scheme=wanderer-app;'
        'package=$packageName;'
        'S.browser_fallback_url=${Uri.encodeComponent(ApiEndpoints.playStoreUrl)};end');
  }

  static Future<void> open(BuildContext context,
      {String? tripId, String? planId, bool install = false}) async {
    final uri = !install && defaultTargetPlatform == TargetPlatform.android
        ? intentUri(tripId: tripId, planId: planId)
        : Uri.parse(ApiEndpoints.playStoreUrl);
    try {
      final launched = await launchUrl(uri,
          webOnlyWindowName: '_self', mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        UiHelpers.showErrorMessage(context, context.l10n.mobileWebLinkError);
      }
    } catch (e) {
      debugPrint('Android app handoff failed: $e');
      if (context.mounted) {
        UiHelpers.showErrorMessage(context, context.l10n.mobileWebLinkError);
      }
    }
  }
}
