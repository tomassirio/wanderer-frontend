import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// "Load more" pagination control shown at the bottom of the home feed's
/// Feed/Discover tabs once more trips are available to fetch.
class LoadMoreTripsButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onLoadMore;

  const LoadMoreTripsButton({
    super.key,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: WandererTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              )
            : TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(
                  Icons.expand_more,
                  color: WandererTheme.primaryOrange,
                ),
                label: Text(
                  l10n.loadMoreTrips,
                  style: const TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }
}
