import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../theme/theme_controller.dart';
import '../app_state.dart';
import '../format.dart';
import '../../theme/app_theme.dart';

/// Loads data from the repository and shows loading / error / content.
/// Reloads automatically whenever the repository changes.
class RepoBuilder<T> extends StatefulWidget {
  const RepoBuilder({super.key, required this.load, required this.builder, this.reloadKey});

  final Future<T> Function(CarpRepository repo) load;
  final Widget Function(BuildContext context, T data) builder;

  /// Change this (e.g. the user id) to force a fresh load.
  final Object? reloadKey;

  @override
  State<RepoBuilder<T>> createState() => _RepoBuilderState<T>();
}

class _RepoBuilderState<T> extends State<RepoBuilder<T>> {
  CarpRepository? _repo;
  T? _data;
  Object? _error;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.read(context).repo;
    if (repo != _repo) {
      _repo?.removeListener(_load);
      _repo = repo..addListener(_load);
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant RepoBuilder<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) {
      _data = null;
      _load();
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request; // ignore answers to older requests
    try {
      final data = await widget.load(_repo!);
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _data == null) {
      return ErrorView(message: _error.toString(), onRetry: () {
        setState(() => _error = null);
        _load();
      });
    }
    if (_data == null) return const LoadingView();
    return widget.builder(context, _data as T);
  }
}

/// Sun/moon button for the app bar: one tap flips light <-> dark.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final dark = ThemeController.isDark(context);
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () => app.theme.setDark(!dark),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: Gap.m),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Gap.s),
              Text(message!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: Gap.m), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: message,
        action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
      );
}

/// "Coming soon" placeholder (used for the Map tab).
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: icon,
        title: title,
        message: message,
        action: Chip(
          label: Text('Coming soon',
              style: TextStyle(color: context.palette.highlightText, fontWeight: FontWeight.w700)),
          avatar: Icon(Icons.schedule, size: 18, color: context.palette.highlight),
          backgroundColor: context.palette.highlight.withValues(alpha: 0.15),
          side: BorderSide(color: context.palette.highlight),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.l, Gap.xs, Gap.s),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      )),
            ),
            ?trailing,
          ],
        ),
      );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.radius = 20});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      child: Text(initials,
          style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700, fontSize: radius * 0.75)),
    );
  }
}

/// Small colored label, e.g. "Full", "Pending", "Edited".
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

/// Shows a balance: red "owes Rs X", green "credit Rs X", or "settled".
class BalanceText extends StatelessWidget {
  const BalanceText(this.balance, {super.key, this.style, this.owesLabel = 'owes'});

  final int balance;
  final TextStyle? style;
  final String owesLabel;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium!;
    if (balance > 0) {
      return Text('$owesLabel ${rs(balance)}', style: base.copyWith(color: context.palette.owesText, fontWeight: FontWeight.w700));
    }
    if (balance < 0) {
      return Text('credit ${rs(-balance)}', style: base.copyWith(color: context.palette.successText, fontWeight: FontWeight.w700));
    }
    return Text('settled', style: base.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

/// A button that disables itself and shows a spinner while working.
/// This also stops accidental double taps.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false});

  final String label;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final bool outlined;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final icon = _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : (widget.icon != null ? Icon(widget.icon) : null);
    final label = Text(widget.label);
    if (widget.outlined) {
      return icon == null
          ? OutlinedButton(onPressed: onPressed, child: label)
          : OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label);
    }
    return icon == null
        ? FilledButton(onPressed: onPressed, child: label)
        : FilledButton.icon(onPressed: onPressed, icon: icon, label: label);
  }
}

/// Runs a repository action and shows a snackbar with the result.
/// Returns true on success.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on CarpException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: errorColor));
    return false;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    return false;
  }
}

/// Simple yes/no dialog.
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Yes'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Keeps a list readable on wide screens (Chrome) and full width on phones.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
