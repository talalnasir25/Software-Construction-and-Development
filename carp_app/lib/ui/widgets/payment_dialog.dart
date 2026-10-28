import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../format.dart';
import '../theme.dart';

/// Asks for amount + method. [onSubmit] does the actual save and may throw
/// a CarpException (e.g. duplicate payment), which is shown in the dialog.
Future<bool> showPaymentDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int suggested,
  required Future<void> Function(int amount, PaymentMethod method) onSubmit,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PaymentDialog(title: title, subtitle: subtitle, suggested: suggested, onSubmit: onSubmit),
  );
  return ok ?? false;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.title, required this.subtitle, required this.suggested, required this.onSubmit});

  final String title;
  final String subtitle;
  final int suggested;
  final Future<void> Function(int amount, PaymentMethod method) onSubmit;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: widget.suggested > 0 ? '${widget.suggested}' : '');
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount in whole rupees, e.g. 500.');
      return;
    }
    setState(() {
      _busy = true; // button disabled while saving = no double tap
      _error = null;
    });
    try {
      await widget.onSubmit(amount, _method);
      if (mounted) Navigator.pop(context, true);
    } on CarpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final over = widget.suggested > 0 && amount > widget.suggested ? amount - widget.suggested : 0;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtitle),
            const SizedBox(height: Gap.m),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs '),
              onChanged: (_) => setState(() {}),
            ),
            if (over > 0)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text('${rs(over)} extra will become credit.', style: const TextStyle(color: CarpColors.credit)),
              ),
            const SizedBox(height: Gap.m),
            const Text('Paid via'),
            const SizedBox(height: Gap.s),
            Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
              for (final m in PaymentMethod.values)
                ChoiceChip(label: Text(m.label), selected: _method == m, onSelected: (_) => setState(() => _method = m)),
            ]),
            if (_error != null) ...[
              const SizedBox(height: Gap.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
