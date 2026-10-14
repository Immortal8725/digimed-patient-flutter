import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class DigiMedApp extends ConsumerWidget {
  const DigiMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    return SessionListener(
      child: MaterialApp.router(
        title: 'DigiMed Connect',
        theme: buildDigimedTheme(Brightness.light),
        darkTheme: buildDigimedTheme(Brightness.dark),
        themeMode: mode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
