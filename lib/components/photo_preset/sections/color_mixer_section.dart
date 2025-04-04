import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/components/photo_preset/subsection_header.dart';
import 'package:photobooth/models/preset_model.dart';

class ColorMixerSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final Map<String, double?> tempValues;
  final Function(double) updateRedHue;
  final Function(double) updateRedSaturation;
  final Function(double) updateRedLuminance;
  final Function(double) updateGreenHue;
  final Function(double) updateGreenSaturation;
  final Function(double) updateGreenLuminance;
  final Function(double) updateBlueHue;
  final Function(double) updateBlueSaturation;
  final Function(double) updateBlueLuminance;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const ColorMixerSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.tempValues,
    required this.updateRedHue,
    required this.updateRedSaturation,
    required this.updateRedLuminance,
    required this.updateGreenHue,
    required this.updateGreenSaturation,
    required this.updateGreenLuminance,
    required this.updateBlueHue,
    required this.updateBlueSaturation,
    required this.updateBlueLuminance,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Color Mixer',
      initiallyExpanded: false,
      children: [
        const SubsectionHeader(title: 'Red'),
        _buildColorChannelSliders(
          'Red',
          Colors.red,
          tempValues['redHue'] ?? preset.redHue,
          tempValues['redSaturation'] ?? preset.redSaturation,
          tempValues['redLuminance'] ?? preset.redLuminance,
          updateRedHue,
          updateRedSaturation,
          updateRedLuminance,
          (value) {
            onPresetUpdated(preset.copyWith(redHue: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(redSaturation: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(redLuminance: value));
            onUpdatePreview();
          },
        ),

        const SubsectionHeader(title: 'Green'),
        _buildColorChannelSliders(
          'Green',
          Colors.green,
          tempValues['greenHue'] ?? preset.greenHue,
          tempValues['greenSaturation'] ?? preset.greenSaturation,
          tempValues['greenLuminance'] ?? preset.greenLuminance,
          updateGreenHue,
          updateGreenSaturation,
          updateGreenLuminance,
          (value) {
            onPresetUpdated(preset.copyWith(greenHue: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(greenSaturation: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(greenLuminance: value));
            onUpdatePreview();
          },
        ),

        const SubsectionHeader(title: 'Blue'),
        _buildColorChannelSliders(
          'Blue',
          Colors.blue,
          tempValues['blueHue'] ?? preset.blueHue,
          tempValues['blueSaturation'] ?? preset.blueSaturation,
          tempValues['blueLuminance'] ?? preset.blueLuminance,
          updateBlueHue,
          updateBlueSaturation,
          updateBlueLuminance,
          (value) {
            onPresetUpdated(preset.copyWith(blueHue: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(blueSaturation: value));
            onUpdatePreview();
          },
          (value) {
            onPresetUpdated(preset.copyWith(blueLuminance: value));
            onUpdatePreview();
          },
        ),

        const SizedBox(height: 16),
        Center(
          child: Text(
            'Adjust individual colors for creative control',
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

  Widget _buildColorChannelSliders(
    String channel,
    Color color,
    double hue,
    double saturation,
    double luminance,
    Function(double) onHueChanged,
    Function(double) onSaturationChanged,
    Function(double) onLuminanceChanged,
    Function(double) onHueChangeEnd,
    Function(double) onSaturationChangeEnd,
    Function(double) onLuminanceChangeEnd,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 20,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          // Sliders
          Expanded(
            child: Column(
              children: [
                SliderSetting(
                  label: 'Hue',
                  value: hue,
                  min: -1.0,
                  max: 1.0,
                  onChanged: onHueChanged,
                  onChangeEnd: onHueChangeEnd,
                  enabled: isEditing,
                ),
                SliderSetting(
                  label: 'Saturation',
                  value: saturation,
                  min: -1.0,
                  max: 1.0,
                  onChanged: onSaturationChanged,
                  onChangeEnd: onSaturationChangeEnd,
                  enabled: isEditing,
                ),
                SliderSetting(
                  label: 'Luminance',
                  value: luminance,
                  min: -1.0,
                  max: 1.0,
                  onChanged: onLuminanceChanged,
                  onChangeEnd: onLuminanceChangeEnd,
                  enabled: isEditing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
