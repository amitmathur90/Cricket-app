import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/network_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: AmmctApp()));
}

class AmmctApp extends ConsumerStatefulWidget {
  const AmmctApp({super.key});

  @override
  ConsumerState<AmmctApp> createState() => _AmmctAppState();
}

class _AmmctAppState extends ConsumerState<AmmctApp> {
  @override
  void initState() {
    super.initState();
    // Fired once, independent of login/session state — see
    // ApiClient.warmUp's doc comment for why (a logged-out launch never
    // touches the network otherwise, so a cold Render backend would only
    // start waking up once the user submits the login form).
    ref.read(apiClientProvider).warmUp();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Ammct Cricket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
