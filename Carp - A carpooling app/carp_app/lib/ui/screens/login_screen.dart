import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// DEMO login: any email + password works.
/// Real login will only accept "@isbstudent.comsats.edu.pk" emails
/// (students and faculty), verified on the server.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(context);
    AppUser? user;
    await runAction(context, () async {
      user = await app.repo.login(_email.text, _password.text);
    });
    if (user != null) app.signIn(user!);
  }

  void _useDemo(AppUser u) {
    _email.text = u.email;
    _password.text = 'demo1234';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton(), SizedBox(width: Gap.s)]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.l),
            child: Constrained(
              maxWidth: 420,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.directions_car_filled, size: 40, color: scheme.onPrimary),
                    ),
                    const SizedBox(height: Gap.m),
                    Text('Carp',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary)),
                    Text('Share rides to campus. Split the cost.',
                        textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: Gap.xl),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'University email',
                        hintText: 'name@isbstudent.comsats.edu.pk',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Please enter a valid email.' : null,
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Please enter a password.' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: Gap.l),
                    BusyButton(label: 'Log in', icon: Icons.login, onPressed: _login),
                    const SizedBox(height: Gap.l),
                    Card(
                      color: scheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
                              const SizedBox(width: Gap.s),
                              Text('Demo mode', style: theme.textTheme.titleSmall),
                            ]),
                            const SizedBox(height: Gap.s),
                            const Text('Any email and password works tonight. The real app will only allow '
                                '@isbstudent.comsats.edu.pk emails (students and faculty), verified by the server.'),
                            const SizedBox(height: Gap.m),
                            const Text('Quick fill a demo user:'),
                            const SizedBox(height: Gap.s),
                            RepoBuilder<List<AppUser>>(
                              load: (repo) => repo.demoUsers(),
                              builder: (context, users) => Wrap(
                                spacing: Gap.s,
                                runSpacing: Gap.s,
                                children: [
                                  for (final u in users)
                                    ActionChip(
                                      avatar: Icon(u.vehicleType == null ? Icons.person : Icons.directions_car, size: 18),
                                      label: Text(u.name),
                                      onPressed: () => _useDemo(u),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
