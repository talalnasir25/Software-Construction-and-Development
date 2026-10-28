import 'package:flutter/material.dart';

import 'data/in_memory_repository.dart';
import 'ui/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';

void main() {
  // Swap InMemoryCarpRepository for an API-backed repository later.
  final state = AppState(InMemoryCarpRepository());
  runApp(CarpApp(state: state));
}

class CarpApp extends StatelessWidget {
  const CarpApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Carp',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

/// Shows login or the main app depending on who is signed in.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: user == null ? const LoginScreen() : HomeShell(key: ValueKey(user.id)),
    );
  }
}
