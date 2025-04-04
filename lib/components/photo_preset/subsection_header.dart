import 'package:flutter/material.dart';

class SubsectionHeader extends StatelessWidget {
  final String title;

  const SubsectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 14,
            ),
          ),
          Divider(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            height: 8,
            thickness: 1,
          ),
        ],
      ),
    );
  }
}
