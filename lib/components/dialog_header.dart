import 'package:flutter/material.dart';

/// A reusable header for dialogs.
class DialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const DialogHeader({Key? key, required this.title, required this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ],
    );
  }
}
