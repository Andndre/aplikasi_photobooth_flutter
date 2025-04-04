import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/components/photo_preset/subsection_header.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';

class SettingsPanel extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final PresetProvider presetProvider;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;
  final Function(BuildContext) onPickColor;
  final String? eventId;
  final Map<String, double?> tempValues;
  final Function() onCancel;

  // Parameters for updating sliders
  final Function(double) updateBrightness;
  final Function(double) updateContrast;
  final Function(double) updateSaturation;
  final Function(double) updateBorderWidth;
  final Function(double) updateTemperature;
  final Function(double) updateTint;
  final Function(double) updateExposure;
  final Function(double) updateHighlights;
  final Function(double) updateShadows;
  final Function(double) updateWhites;
  final Function(double) updateBlacks;
  final Function(bool) updateBlackAndWhite;
  final Function() pickSampleImage;

  const SettingsPanel({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.presetProvider,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
    required this.onPickColor,
    this.eventId,
    required this.tempValues,
    required this.onCancel,
    required this.updateBrightness,
    required this.updateContrast,
    required this.updateSaturation,
    required this.updateBorderWidth,
    required this.updateTemperature,
    required this.updateTint,
    required this.updateExposure,
    required this.updateHighlights,
    required this.updateShadows,
    required this.updateWhites,
    required this.updateBlacks,
    required this.updateBlackAndWhite,
    required this.pickSampleImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Preset' : preset.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isEditing)
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    tooltip: 'Set as Active',
                    onPressed: () {
                      presetProvider.setActivePreset(preset.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${preset.name} set as active preset'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
              ],
            ),

            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickSampleImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Change Sample Image'),
                      ),
                    ),
                  ],
                ),
              ),

            // Preset name edit field in edit mode
            if (isEditing) ...[
              TextFormField(
                initialValue: preset.name,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  onPresetUpdated(preset.copyWith(name: value));
                },
              ),
              const SizedBox(height: 16),
            ],

            // Collapsible Basic section containing all adjustments
            CollapsibleSection(
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
                  onChanged: (value) {
                    updateTemperature(value);
                  },
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
                  onChanged: (value) {
                    updateTint(value);
                  },
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
                  onChanged: (value) {
                    updateExposure(value);
                  },
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
                  onChanged: (value) {
                    updateHighlights(value);
                  },
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
                  onChanged: (value) {
                    updateShadows(value);
                  },
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
                  onChanged: (value) {
                    updateWhites(value);
                  },
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
                  onChanged: (value) {
                    updateBlacks(value);
                  },
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
                  onChanged: (value) {
                    updateBrightness(value);
                  },
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
                  onChanged: (value) {
                    updateContrast(value);
                  },
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
                  onChanged: (value) {
                    updateSaturation(value);
                  },
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
            ),

            const SizedBox(height: 8),

            // Separate collapsible Effects section for border width
            CollapsibleSection(
              title: 'Effects',
              initiallyExpanded: true,
              children: [
                const SubsectionHeader(title: 'Border'),
                SliderSetting(
                  label: 'Border Width',
                  value: tempValues['borderWidth'] ?? preset.borderWidth,
                  min: 0.0,
                  max: 10.0,
                  onChanged: (value) {
                    updateBorderWidth(value);
                  },
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
            ),

            const SizedBox(height: 16),

            // Save/Cancel buttons when editing
            if (isEditing)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final updatedPreset = preset;
                      presetProvider.updatePreset(updatedPreset);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${updatedPreset.name} updated'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),

            if (eventId != null && !isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Apply to Event'),
                  onPressed: () {
                    // Here we would apply the preset to the event
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${preset.name} applied to event'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
