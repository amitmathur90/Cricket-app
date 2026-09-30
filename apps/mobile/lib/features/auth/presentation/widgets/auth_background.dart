import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared navy hero background for the auth screens (splash/login/register)
/// — a gradient plus a few soft "bokeh" circles standing in for the
/// mockup's stadium-lights photo, since no image assets exist in this
/// project yet (no `assets/` folder, nothing declared in `pubspec.yaml`).
/// Purely decorative — wraps [child] in a [Stack] over the gradient,
/// nothing here touches auth state/logic.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF14235B), AppColors.primaryDark],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: -60, right: -40, child: _Bokeh(size: 180, opacity: 0.10)),
          const Positioned(bottom: -80, left: -60, child: _Bokeh(size: 220, opacity: 0.08)),
          const Positioned(top: 160, left: -30, child: _Bokeh(size: 90, opacity: 0.06)),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _Bokeh extends StatelessWidget {
  const _Bokeh({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryLight.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// The circular bat-and-ball logo mark used on splash/login — a plain
/// [Icon] inside a white circle stands in for the mockup's illustrated
/// mark, same "no image assets yet" reasoning as [AuthBackground].
class AuthLogoMark extends StatelessWidget {
  const AuthLogoMark({super.key, this.radius = 44});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Icon(Icons.sports_cricket, size: radius, color: AppColors.navy),
    );
  }
}
