import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// A reusable folder selector component that allows selecting a directory path.
class FolderSelector extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String selectedPath;
  final Function(String) onSelectFolder;
  final bool required;

  const FolderSelector({
    Key? key,
    required this.label,
    required this.hint,
    this.icon = Icons.folder,
    required this.selectedPath,
    required this.onSelectFolder,
    this.required = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            if (required)
              Text(
                '*',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: ListTile(
            leading: Icon(icon),
            title:
                selectedPath.isEmpty
                    ? Text(
                      hint,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                    : Text(selectedPath, overflow: TextOverflow.ellipsis),
            trailing:
                selectedPath.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onSelectFolder(''),
                    )
                    : null,
            onTap: () async {
              String? selectedDirectory =
                  await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null) {
                onSelectFolder(selectedDirectory);
              }
            },
          ),
        ),
      ],
    );
  }
}
