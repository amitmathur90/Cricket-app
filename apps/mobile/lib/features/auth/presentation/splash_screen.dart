import 'package:flutter/material.dart';

/// Shown only while [SessionController] is resolving stored tokens on app
/// launch (`AuthStatus.unknown`) — the router redirects away from here as
/// soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
