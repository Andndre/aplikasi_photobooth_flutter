import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/sections/action_buttons_section.dart';
import 'package:photobooth/components/photo_preset/sections/basic_section.dart';
import 'package:photobooth/components/photo_preset/sections/color_mixer_section.dart';
import 'package:photobooth/components/photo_preset/sections/detail_section.dart';
import 'package:photobooth/components/photo_preset/sections/preset_info_section.dart';
import 'package:photobooth/components/photo_preset/sections/tone_curve_section.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:photobooth/components/photo_preset/sections/color_grading_section.dart';

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
  final String? currentEventId;
  final Function(String) onSetAsActiveForEvent;

  // Parameters for updating sliders - Basic
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

  // Parameters for updating sliders - Color Mixer
  final Function(double) updateRedHue;
  final Function(double) updateRedSaturation;
  final Function(double) updateRedLuminance;
  final Function(double) updateGreenHue;
  final Function(double) updateGreenSaturation;
  final Function(double) updateGreenLuminance;
  final Function(double) updateBlueHue;
  final Function(double) updateBlueSaturation;
  final Function(double) updateBlueLuminance;

  // Detail section callbacks
  final Function(double) updateSharpness;
  final Function(double) updateDetail;
  final Function(double) updateNoiseReduction;

  final Function() pickSampleImage;

  // Color grading callbacks
  final Function(Color) updateShadowsColor;
  final Function(double) updateShadowsIntensity;
  final Function(Color) updateMidtonesColor;
  final Function(double) updateMidtonesIntensity;
  final Function(Color) updateHighlightsColor;
  final Function(double) updateHighlightsIntensity;
  final Function(double) updateColorBalance;

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
    required this.currentEventId,
    required this.onSetAsActiveForEvent,
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
    required this.updateRedHue,
    required this.updateRedSaturation,
    required this.updateRedLuminance,
    required this.updateGreenHue,
    required this.updateGreenSaturation,
    required this.updateGreenLuminance,
    required this.updateBlueHue,
    required this.updateBlueSaturation,
    required this.updateBlueLuminance,
    required this.updateSharpness,
    required this.updateDetail,
    required this.updateNoiseReduction,
    required this.pickSampleImage,
    required this.updateShadowsColor,
    required this.updateShadowsIntensity,
    required this.updateMidtonesColor,
    required this.updateMidtonesIntensity,
    required this.updateHighlightsColor,
    required this.updateHighlightsIntensity,
    required this.updateColorBalance,
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
            // Preset Info Section (Header)
            PresetInfoSection(
              preset: preset,
              isEditing: isEditing,
              presetProvider: presetProvider,
              onPresetUpdated: onPresetUpdated,
              pickSampleImage: pickSampleImage,
              // Pass the new parameters
              currentEventId: currentEventId,
              onSetAsActiveForEvent: onSetAsActiveForEvent,
            ),

            // Basic Section (White Balance, Tone, Presence)
            BasicSection(
              preset: preset,
              isEditing: isEditing,
              tempValues: tempValues,
              updateTemperature: updateTemperature,
              updateTint: updateTint,
              updateExposure: updateExposure,
              updateHighlights: updateHighlights,
              updateShadows: updateShadows,
              updateWhites: updateWhites,
              updateBlacks: updateBlacks,
              updateBrightness: updateBrightness,
              updateContrast: updateContrast,
              updateSaturation: updateSaturation,
              updateBlackAndWhite: updateBlackAndWhite,
              onPresetUpdated: onPresetUpdated,
              onUpdatePreview: onUpdatePreview,
            ),

            const SizedBox(height: 8),

            // Detail enhancements section
            DetailSection(
              preset: preset,
              isEditing: isEditing,
              tempValues: tempValues,
              updateSharpness: updateSharpness,
              updateDetail: updateDetail,
              updateNoiseReduction: updateNoiseReduction,
              onPresetUpdated: onPresetUpdated,
              onUpdatePreview: onUpdatePreview,
            ),

            const SizedBox(height: 8),

            // Tone Curve Section
            ToneCurveSection(
              preset: preset,
              isEditing: isEditing,
              onPresetUpdated: onPresetUpdated,
              onUpdatePreview: onUpdatePreview,
            ),

            const SizedBox(height: 8),

            // Color Mixer Section
            ColorMixerSection(
              preset: preset,
              isEditing: isEditing,
              tempValues: tempValues,
              updateRedHue: updateRedHue,
              updateRedSaturation: updateRedSaturation,
              updateRedLuminance: updateRedLuminance,
              updateGreenHue: updateGreenHue,
              updateGreenSaturation: updateGreenSaturation,
              updateGreenLuminance: updateGreenLuminance,
              updateBlueHue: updateBlueHue,
              updateBlueSaturation: updateBlueSaturation,
              updateBlueLuminance: updateBlueLuminance,
              onPresetUpdated: onPresetUpdated,
              onUpdatePreview: onUpdatePreview,
            ),

            const SizedBox(height: 8),

            // Color Grading Section
            ColorGradingSection(
              preset: preset,
              isEditing: isEditing,
              tempValues: tempValues,
              updateShadowsColor: updateShadowsColor,
              updateShadowsIntensity: updateShadowsIntensity,
              updateMidtonesColor: updateMidtonesColor,
              updateMidtonesIntensity: updateMidtonesIntensity,
              updateHighlightsColor: updateHighlightsColor,
              updateHighlightsIntensity: updateHighlightsIntensity,
              updateColorBalance: updateColorBalance,
              onPresetUpdated: onPresetUpdated,
              onUpdatePreview: onUpdatePreview,
            ),

            // Action Buttons Section (Footer)
            ActionButtonsSection(
              preset: preset,
              isEditing: isEditing,
              presetProvider: presetProvider,
              onCancel: onCancel,
              eventId: eventId,
            ),
          ],
        ),
      ),
    );
  }
}
