import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/widgets/common/legal_document.dart';

/// Full-page Privacy Policy for its direct link; in the app it opens as a popup
/// ([showLegalDocument]).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(LegalDocument.privacy.title(context))),
        body: const LegalDocumentView(LegalDocument.privacy),
      );
}
