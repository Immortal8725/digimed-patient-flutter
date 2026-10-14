import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';
import '../../features/auth/auth_controller.dart';

class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final label = switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'theme') {
          await ref.read(themeModeProvider.notifier).cycle();
        } else if (value == 'logout') {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'theme', child: Text('Theme: $label')),
        const PopupMenuItem(value: 'logout', child: Text('Sign out')),
      ],
    );
  }
}
