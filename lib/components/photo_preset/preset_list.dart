import 'package:flutter/material.dart';
import 'package:photobooth/models/preset_model.dart';

class PresetList extends StatelessWidget {
  final List<PresetModel> presets;
  final PresetModel? activePreset;
  final PresetModel? selectedPreset;
  final Function(PresetModel) onPresetSelected;
  final Function(String) onPresetDelete;

  const PresetList({
    super.key,
    required this.presets,
    required this.activePreset,
    required this.selectedPreset,
    required this.onPresetSelected,
    required this.onPresetDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, // Fixed width for preset list
      child: Card(
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ListView.builder(
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final preset = presets[index];
            final isActive = preset.id == activePreset?.id;

            return ListTile(
              title: Text(preset.name),
              selected: selectedPreset?.id == preset.id,
              leading:
                  isActive
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.photo_filter),
              trailing:
                  preset.id != 'default'
                      ? IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => onPresetDelete(preset.id),
                      )
                      : null,
              onTap: () => onPresetSelected(preset),
            );
          },
        ),
      ),
    );
  }
}
