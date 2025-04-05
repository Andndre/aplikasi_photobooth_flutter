import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/models/preset_model.dart';

class DetailSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final Map<String, double?> tempValues;
  final Function(double) updateSharpness;
  final Function(double) updateDetail;
  final Function(double) updateNoiseReduction;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const DetailSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.tempValues,
    required this.updateSharpness,
    required this.updateDetail,
    required this.updateNoiseReduction,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Detail',
      initiallyExpanded: false,
      children: [
        SliderSetting(
          label: 'Sharpness',
          value: tempValues['sharpness'] ?? preset.sharpness,
          min: 0.0,
          max: 1.0,
          onChanged: updateSharpness,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(sharpness: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'None',
          rightLabel: 'High',
        ),

        SliderSetting(
          label: 'Detail',
          value: tempValues['detail'] ?? preset.detail,
          min: 0.0,
          max: 1.0,
          onChanged: updateDetail,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(detail: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Low',
          rightLabel: 'High',
        ),

        SliderSetting(
          label: 'Noise Reduction',
          value: tempValues['noiseReduction'] ?? preset.noiseReduction,
          min: 0.0,
          max: 1.0,
          onChanged: updateNoiseReduction,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(noiseReduction: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'None',
          rightLabel: 'High',
        ),

        const SizedBox(height: 8),

        Center(
          child: Text(
            'Enhance image details, sharpness, and reduce visual noise',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
