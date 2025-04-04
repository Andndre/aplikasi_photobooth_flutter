import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/components/photo_preset/subsection_header.dart';
import 'package:photobooth/models/preset_model.dart';

class BasicSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final Map<String, double?> tempValues;
  final Function(double) updateTemperature;
  final Function(double) updateTint;
  final Function(double) updateExposure;
  final Function(double) updateHighlights;
  final Function(double) updateShadows;
  final Function(double) updateWhites;
  final Function(double) updateBlacks;
  final Function(double) updateBrightness;
  final Function(double) updateContrast;
  final Function(double) updateSaturation;
  final Function(bool) updateBlackAndWhite;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const BasicSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.tempValues,
    required this.updateTemperature,
    required this.updateTint,
    required this.updateExposure,
    required this.updateHighlights,
    required this.updateShadows,
    required this.updateWhites,
    required this.updateBlacks,
    required this.updateBrightness,
    required this.updateContrast,
    required this.updateSaturation,
    required this.updateBlackAndWhite,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Basic',
      initiallyExpanded: true,
      children: [
        // White Balance subsection
        const SubsectionHeader(title: 'White Balance'),
        SliderSetting(
          label: 'Temperature',
          value: tempValues['temperature'] ?? preset.temperature,
          min: -1.0,
          max: 1.0,
          onChanged: updateTemperature,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(temperature: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Cool',
          rightLabel: 'Warm',
        ),

        SliderSetting(
          label: 'Tint',
          value: tempValues['tint'] ?? preset.tint,
          min: -1.0,
          max: 1.0,
          onChanged: updateTint,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(tint: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Green',
          rightLabel: 'Magenta',
        ),

        // Tone subsection
        const SubsectionHeader(title: 'Tone'),
        SliderSetting(
          label: 'Exposure',
          value: tempValues['exposure'] ?? preset.exposure,
          min: -1.0,
          max: 1.0,
          onChanged: updateExposure,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(exposure: value));
            onUpdatePreview();
          },
          enabled: isEditing,
        ),

        SliderSetting(
          label: 'Highlights',
          value: tempValues['highlights'] ?? preset.highlights,
          min: -1.0,
          max: 1.0,
          onChanged: updateHighlights,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(highlights: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Increase',
          rightLabel: 'Reduce',
        ),

        SliderSetting(
          label: 'Shadows',
          value: tempValues['shadows'] ?? preset.shadows,
          min: -1.0,
          max: 1.0,
          onChanged: updateShadows,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(shadows: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Darker',
          rightLabel: 'Brighter',
        ),

        SliderSetting(
          label: 'Whites',
          value: tempValues['whites'] ?? preset.whites,
          min: -1.0,
          max: 1.0,
          onChanged: updateWhites,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(whites: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Reduce',
          rightLabel: 'Increase',
        ),

        SliderSetting(
          label: 'Blacks',
          value: tempValues['blacks'] ?? preset.blacks,
          min: -1.0,
          max: 1.0,
          onChanged: updateBlacks,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(blacks: value));
            onUpdatePreview();
          },
          enabled: isEditing,
          leftLabel: 'Deepen',
          rightLabel: 'Lighten',
        ),

        // Presence subsection
        const SubsectionHeader(title: 'Presence'),
        SliderSetting(
          label: 'Brightness',
          value: tempValues['brightness'] ?? preset.brightness,
          min: -1.0,
          max: 1.0,
          onChanged: updateBrightness,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(brightness: value));
            onUpdatePreview();
          },
          enabled: isEditing,
        ),

        SliderSetting(
          label: 'Contrast',
          value: tempValues['contrast'] ?? preset.contrast,
          min: -1.0,
          max: 1.0,
          onChanged: updateContrast,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(contrast: value));
            onUpdatePreview();
          },
          enabled: isEditing,
        ),

        SliderSetting(
          label: 'Saturation',
          value: tempValues['saturation'] ?? preset.saturation,
          min: -1.0,
          max: 1.0,
          onChanged: updateSaturation,
          onChangeEnd: (value) {
            onPresetUpdated(preset.copyWith(saturation: value));
            onUpdatePreview();
          },
          enabled: isEditing,
        ),

        SwitchListTile(
          title: const Text('Black and White'),
          subtitle: const Text('Convert image to grayscale'),
          value: preset.blackAndWhite,
          onChanged:
              isEditing
                  ? (value) {
                    updateBlackAndWhite(value);
                    onUpdatePreview();
                  }
                  : null,
        ),
      ],
    );
  }
}
