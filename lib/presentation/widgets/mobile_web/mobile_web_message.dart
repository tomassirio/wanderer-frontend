import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

class MobileWebMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool success;

  const MobileWebMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
          child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight:
                    (constraints.maxHeight - 48).clamp(0, double.infinity)),
            child: IntrinsicHeight(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: WandererLogo(size: 36)),
                const Spacer(),
                Center(
                    child: CircleAvatar(
                  radius: 38,
                  backgroundColor: success ? c.forestBg : c.neutralBg,
                  child: Icon(icon,
                      size: 38, color: success ? c.forestFg : c.textMuted),
                )),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: WandererTheme.display(28, color: c.text)),
                const SizedBox(height: 16),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, height: 1.5, color: c.textMuted)),
                const Spacer(),
                const SizedBox(height: 32),
                for (final action in actions) ...[
                  action,
                  const SizedBox(height: 10),
                ],
              ],
            )),
          ),
        ),
      )),
    );
  }
}
