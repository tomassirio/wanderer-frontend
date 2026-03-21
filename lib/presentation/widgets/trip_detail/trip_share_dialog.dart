import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

/// Dialog that shows a QR code and sharing link for a trip
class TripShareDialog extends StatefulWidget {
  final String tripId;
  final String tripName;

  const TripShareDialog({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  /// Shows the trip share dialog as a modal bottom sheet on mobile
  /// or a centered dialog on larger screens.
  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String tripName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => TripShareDialog(
        tripId: tripId,
        tripName: tripName,
      ),
    );
  }

  @override
  State<TripShareDialog> createState() => _TripShareDialogState();
}

class _TripShareDialogState extends State<TripShareDialog> {
  late final String _tripUrl;
  String? _shortUrl;
  bool _isLoadingShortUrl = true;
  String? _shortUrlError;

  @override
  void initState() {
    super.initState();
    _tripUrl = ApiEndpoints.tripDeepLink(widget.tripId);
    _fetchShortUrl();
  }

  Future<void> _fetchShortUrl() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(_tripUrl)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _shortUrl = response.body.trim();
          _isLoadingShortUrl = false;
        });
      } else if (mounted) {
        setState(() {
          _shortUrlError = 'Could not shorten URL';
          _isLoadingShortUrl = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shortUrlError = 'Could not shorten URL';
          _isLoadingShortUrl = false;
        });
      }
    }
  }

  void _copyToClipboard(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    UiHelpers.showSuccessMessage(context, 'Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    Icons.share,
                    color: WandererTheme.primaryOrange,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.shareTrip,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Content
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.tripName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: WandererTheme.glassBorderColorFor(context),
                          width: 1,
                        ),
                      ),
                      child: QrImageView(
                        data: _tripUrl,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Full trip URL
                    _buildUrlRow(
                      context: context,
                      label: 'Trip Link',
                      url: _tripUrl,
                      icon: Icons.link,
                    ),
                    const SizedBox(height: 8),
                    // Shortened URL
                    _buildShortUrlRow(context),
                  ],
                ),
              ),
              // Actions
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlRow({
    required BuildContext context,
    required String label,
    required String url,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              url,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _copyToClipboard(context, url),
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy $label',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: WandererTheme.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildShortUrlRow(BuildContext context) {
    if (_isLoadingShortUrl) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.compress,
                size: 16,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            const Expanded(
              child: SizedBox(
                height: 12,
                child: LinearProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    if (_shortUrlError != null || _shortUrl == null) {
      return const SizedBox.shrink();
    }

    return _buildUrlRow(
      context: context,
      label: 'Short Link',
      url: _shortUrl!,
      icon: Icons.compress,
    );
  }
}
