import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layouts.dart';

/// A reusable dropdown component for selecting a layout.
class LayoutDropdown extends StatelessWidget {
  final int? value;
  final void Function(int?) onChanged;
  final void Function(int?)? onSaved;
  final String? Function(int?)? validator;

  const LayoutDropdown({
    Key? key,
    this.value,
    required this.onChanged,
    this.onSaved,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future:
          Provider.of<LayoutsProvider>(context, listen: false).loadLayouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Consumer<LayoutsProvider>(
          builder: (context, layoutsProvider, child) {
            if (layoutsProvider.layouts.isEmpty) {
              return Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No layouts available. Please create a layout first.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Check if the current layout still exists if a value is provided
            final layoutExists =
                value == null ||
                layoutsProvider.layouts.any((layout) => layout.id == value);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (value != null && !layoutExists)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The previously selected layout no longer exists. Please select a new layout.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Layout',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  value: layoutExists ? value : null,
                  hint: const Text('Select event layout'),
                  items:
                      layoutsProvider.layouts.map((layout) {
                        return DropdownMenuItem<int>(
                          value: layout.id,
                          child: Text(layout.name),
                        );
                      }).toList(),
                  validator:
                      validator ??
                      (value) {
                        if (value == null) {
                          return 'Please select a layout';
                        }
                        return null;
                      },
                  onChanged: onChanged,
                  onSaved: onSaved,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
