import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';

/// Dialog that shows a QR code and sharing link for a trip
class TripShareDialog extends ConsumerStatefulWidget {
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
    Widget builder(BuildContext context) =>
        TripShareDialog(tripId: tripId, tripName: tripName);
    if (kIsWeb) return WandererDialog.show<void>(context, builder: builder);
    return showDialog<void>(context: context, builder: builder);
  }

  @override
  ConsumerState<TripShareDialog> createState() => _TripShareDialogState();
}

class _TripShareDialogState extends ConsumerState<TripShareDialog> {
  late final String _tripUrl;
  late final UrlShortenerService _urlShortenerService;
  String? _shortUrl;
  bool _isLoadingShortUrl = true;
  String? _shortUrlError;

  @override
  void initState() {
    super.initState();
    _tripUrl = ApiEndpoints.tripDeepLink(widget.tripId);
    _urlShortenerService = ref.read(urlShortenerServiceProvider);
    _fetchShortUrl();
  }

  Future<void> _fetchShortUrl() async {
    final shortUrl = await _urlShortenerService.shorten(_tripUrl);
    if (!mounted) return;
    setState(() {
      if (shortUrl != null) {
        _shortUrl = shortUrl;
      } else {
        _shortUrlError = 'Could not shorten URL';
      }
      _isLoadingShortUrl = false;
    });
  }

  void _copyToClipboard(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    UiHelpers.showSuccessMessage(
        context,
        kIsWeb
            ? context.l10n.dialogsShareLinkCopied
            : 'Link copied to clipboard');
  }

  /// Web: canvas info popup (440) — title + close, QR, link rows, one
  /// main action (copy the short link, or the full one while it loads).
  Widget _buildWeb(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.shareTrip,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ),
              const DialogCloseButton(),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              widget.tripName,
              style: TextStyle(fontSize: 14, color: c.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // QR stays black on white in both themes so it scans.
                color: Colors.white,
                borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
                border: Border.all(color: c.line),
              ),
              child: QrImageView(
                data: _tripUrl,
                version: QrVersions.auto,
                size: 188,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildWebUrlRow(c, l10n.dialogsShareTripLink, _tripUrl, Icons.link),
          if (_isLoadingShortUrl) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                  minHeight: 3, color: WandererTheme.trail),
            ),
          ] else if (_shortUrl != null) ...[
            const SizedBox(height: 8),
            _buildWebUrlRow(
                c, l10n.dialogsShareShortLink, _shortUrl!, Icons.compress),
          ],
          const SizedBox(height: 20),
          DialogActions(children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
            ElevatedButton.icon(
              onPressed: () => _copyToClipboard(context, _shortUrl ?? _tripUrl),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l10n.dialogsShareCopyLink),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildWebUrlRow(
      WandererColors c, String label, String url, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
        border: Border.all(color: c.lineSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.caption)),
                Text(url,
                    style: TextStyle(fontSize: 13, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(context, url),
            icon: const Icon(Icons.copy, size: 16),
            tooltip: context.l10n.dialogsShareCopyLink,
            color: c.accentText,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWeb(context);
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
