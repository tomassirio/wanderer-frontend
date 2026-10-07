import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';

/// The bundled legal documents.
enum LegalDocument {
  terms('assets/legal/terms_and_condition.html',
      'Failed to load terms and conditions.'),
  privacy('assets/legal/privacy_policy.html', 'Failed to load privacy policy.');

  final String asset;
  final String loadError;
  const LegalDocument(this.asset, this.loadError);

  String title(BuildContext context) => switch (this) {
        LegalDocument.terms => context.l10n.termsOfService,
        LegalDocument.privacy => context.l10n.privacyPolicy,
      };
}

/// Shows [doc] in a popup: a centred card on wide screens, a bottom sheet on
/// phones (same window as What's new).
Future<void> showLegalDocument(BuildContext context, LegalDocument doc) =>
    WandererDialog.show(
      context,
      width: 600,
      builder: (context) {
        final c = WandererTheme.of(context);
        final height = MediaQuery.sizeOf(context).height;
        return SizedBox(
          height: (height * 0.85).clamp(320.0, 700.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(doc.title(context),
                          style: WandererTheme.display(22, color: c.text)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: context.l10n.close,
                    icon: Icon(Icons.close, color: c.textMuted),
                  ),
                ]),
              ),
              Divider(height: 1, color: c.lineSoft),
              Expanded(child: LegalDocumentView(doc)),
            ],
          ),
        );
      },
    );

/// Scrollable plain-text rendering of a bundled legal document.
class LegalDocumentView extends StatefulWidget {
  final LegalDocument doc;
  const LegalDocumentView(this.doc, {super.key});

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  String? _text;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final html = await rootBundle.loadString(widget.doc.asset);
      if (mounted) setState(() => _text = _stripHtmlTags(html));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(widget.doc.loadError,
                style: TextStyle(fontSize: 16, color: c.text),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: Text(context.l10n.retry)),
          ]),
        ),
      );
    }
    final text = _text;
    if (text == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SelectableText(text,
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
    );
  }
}

/// Strips HTML tags to produce readable plain text.
String _stripHtmlTags(String html) {
  var text = html
      .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
      .replaceAll(RegExp(r'<head[^>]*>.*?</head>', dotAll: true), '')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'</?(div|p|h[1-6])[^>]*>'), '\n')
      .replaceAll(RegExp(r'<li[^>]*>'), '\n• ')
      .replaceAll(RegExp(r'</li>'), '')
      .replaceAll(RegExp(r'</?[uo]l[^>]*>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&nbsp;': ' ',
    '&mdash;': '—',
    '&ldquo;': '“',
    '&rdquo;': '”',
  };
  entities.forEach((k, v) => text = text.replaceAll(k, v));
  return text
      .replaceAll(RegExp(r' +'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
