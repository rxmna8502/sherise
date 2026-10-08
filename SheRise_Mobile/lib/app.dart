import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class SheRiseApp extends ConsumerStatefulWidget {
  const SheRiseApp({super.key});

  @override
  ConsumerState<SheRiseApp> createState() => _SheRiseAppState();
}

class _SheRiseAppState extends ConsumerState<SheRiseApp> {
  @override
  void initState() {
    super.initState();
    // Check stored user authentication on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SheRise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
