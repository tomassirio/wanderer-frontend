import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Error message display widget
class ErrorMessage extends StatelessWidget {
  final String message;

  const ErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Web dark theme only; mobile keeps its original look for now.
    final dark = kIsWeb && Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? scheme.onErrorContainer : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? scheme.errorContainer : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: dark ? scheme.errorContainer : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}
