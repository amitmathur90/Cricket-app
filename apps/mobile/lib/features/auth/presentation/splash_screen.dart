import 'package:flutter/material.dart';

import 'widgets/auth_background.dart';

/// Shown only while [SessionController] is resolving stored tokens on app
/// launch (`AuthStatus.unknown`) — the router redirects away from here as
/// soon as that resolves. The navy hero/logo/tagline below is purely
/// decorative; none of it reacts to auth state — that's the router's job.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuthLogoMark(radius: 52),
              const SizedBox(height: 24),
              Text(
                'CricketArena',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Play  •  Compete  •  Win',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
