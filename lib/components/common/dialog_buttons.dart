import 'package:flutter/material.dart';

/// A reusable set of dialog action buttons.
class DialogButtons extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool isConfirmEnabled;
  final Color? confirmColor;

  const DialogButtons({
    super.key,
    this.cancelText = 'Cancel',
    this.confirmText = 'Confirm',
    required this.onCancel,
    required this.onConfirm,
    this.isConfirmEnabled = true,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: onCancel,
          child: Text(cancelText),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: confirmColor,
          ),
          onPressed: isConfirmEnabled ? onConfirm : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
