import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/components/photo_preset/subsection_header.dart';
import 'package:photobooth/models/preset_model.dart';

class EffectsSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final Map<String, double?> tempValues;
  final Function(double) updateBorderWidth;
  final Function(BuildContext) onPickColor;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const EffectsSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.tempValues,
    required this.updateBorderWidth,
    required this.onPickColor,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Effects',
      initiallyExpanded: true,
      children: [
        const SubsectionHeader(title: 'Border'),
        SliderSetting(
          label: 'Border Width',
          value: tempValues['borderWidth'] ?? preset.borderWidth,
          min: 0.0,
          max: 10.0,
          onChanged: updateBorderWidth,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(borderWidth: value));
            onUpdatePreview();
          },
          enabled: isEditing,
        ),

        if (isEditing &&
            (tempValues['borderWidth'] ?? preset.borderWidth) > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Border Color: '),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => onPickColor(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: preset.borderColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
