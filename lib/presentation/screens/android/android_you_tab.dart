import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/screens/android/profile_android_view.dart';

/// Android "You" tab root (canvas: AndroidProfile). Shown inside
/// [AndroidShell], which provides the bottom nav and the + button.
class AndroidYouTab extends StatelessWidget {
  const AndroidYouTab({super.key});

  @override
  Widget build(BuildContext context) => const ProfileAndroidView(isTab: true);
}
