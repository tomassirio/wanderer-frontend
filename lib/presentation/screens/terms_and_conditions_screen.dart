import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/widgets/common/legal_document.dart';

/// Full-page Terms and Conditions for its direct link; in the app it opens as a popup
/// ([showLegalDocument]).
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(LegalDocument.terms.title(context))),
        body: const LegalDocumentView(LegalDocument.terms),
      );
}
