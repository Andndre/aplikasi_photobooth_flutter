import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/components/photo_preset/slider_setting.dart';
import 'package:photobooth/components/photo_preset/subsection_header.dart';
import 'package:photobooth/models/preset_model.dart';

class ColorGradingSection extends StatefulWidget {
  final PresetModel preset;
  final bool isEditing;
  final Map<String, double?> tempValues;

  final Function(Color) updateShadowsColor;
  final Function(double) updateShadowsIntensity;
  final Function(Color) updateMidtonesColor;
  final Function(double) updateMidtonesIntensity;
  final Function(Color) updateHighlightsColor;
  final Function(double) updateHighlightsIntensity;
  final Function(double) updateColorBalance;

  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const ColorGradingSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.tempValues,
    required this.updateShadowsColor,
    required this.updateShadowsIntensity,
    required this.updateMidtonesColor,
    required this.updateMidtonesIntensity,
    required this.updateHighlightsColor,
    required this.updateHighlightsIntensity,
    required this.updateColorBalance,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  State<ColorGradingSection> createState() => _ColorGradingSectionState();
}

class _ColorGradingSectionState extends State<ColorGradingSection> {
  String _selectedRegion = 'midtones';
  bool _isDraggingWheel = false;

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Color Grading',
      initiallyExpanded: false,
      children: [
        _buildRegionSelector(),
        const SizedBox(height: 16),

        // Color wheel based on selected region
        if (_selectedRegion == 'shadows')
          _buildColorWheel(
            'Shadows',
            widget.preset.shadowsColor,
            widget.preset.shadowsIntensity,
            widget.updateShadowsColor,
            widget.updateShadowsIntensity,
            Colors.blue.shade800,
          )
        else if (_selectedRegion == 'midtones')
          _buildColorWheel(
            'Midtones',
            widget.preset.midtonesColor,
            widget.preset.midtonesIntensity,
            widget.updateMidtonesColor,
            widget.updateMidtonesIntensity,
            Colors.grey,
          )
        else if (_selectedRegion == 'highlights')
          _buildColorWheel(
            'Highlights',
            widget.preset.highlightsColor,
            widget.preset.highlightsIntensity,
            widget.updateHighlightsColor,
            widget.updateHighlightsIntensity,
            Colors.yellow.shade300,
          ),

        const SizedBox(height: 16),

        // Global settings for color grading
        const SubsectionHeader(title: 'Global'),
        SliderSetting(
          label: 'Color Balance',
          value:
              widget.tempValues['colorBalance'] ?? widget.preset.colorBalance,
          min: -1.0,
          max: 1.0,
          onChanged: widget.updateColorBalance,
          onChangeEnd: (value) {
            widget.onPresetUpdated(widget.preset.copyWith(colorBalance: value));
            widget.onUpdatePreview();
          },
          enabled: widget.isEditing,
          leftLabel: 'Shadows',
          rightLabel: 'Highlights',
        ),
      ],
    );
  }

  Widget _buildRegionSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'shadows',
          label: Text('Shadows', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: 'midtones',
          label: Text('Midtones', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: 'highlights',
          label: Text('Highlight', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {_selectedRegion},
      onSelectionChanged:
          widget.isEditing
              ? (Set<String> selection) {
                setState(() {
                  _selectedRegion = selection.first;
                });
              }
              : null,
      showSelectedIcon: false,
    );
  }

  Widget _buildColorWheel(
    String title,
    Color color,
    double intensity,
    Function(Color) onColorChanged,
    Function(double) onIntensityChanged,
    Color baseColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and intensity value
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text('${(intensity * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),

        // Color wheel
        Container(
          height: 200,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Color wheel background
              CustomPaint(
                size: const Size(200, 200),
                painter: ColorWheelPainter(),
              ),

              // Current color indicator
              if (widget.isEditing) _buildColorIndicator(color, intensity),

              // Interactive color selector
              if (widget.isEditing)
                GestureDetector(
                  onPanStart: (_) {
                    setState(() {
                      _isDraggingWheel = true;
                    });
                  },
                  onPanUpdate: (details) {
                    // Calculate position relative to center
                    final center = const Offset(100, 100);
                    final position = details.localPosition - center;

                    // Convert position to polar coordinates
                    final radius = math.min(100, position.distance);

                    // Calculate the angle directly from the position
                    // This gives us correct orientation (0° is right, 90° is bottom)
                    double angle = math.atan2(position.dy, position.dx);

                    // Convert polar coordinates to HSV
                    // Map to HSV hue (0-360), converting from radians to degrees
                    final hue = ((angle * 180 / math.pi) + 180) % 360;
                    final saturation = radius / 100;

                    // Create new color
                    final newColor =
                        HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();
                    onColorChanged(newColor);

                    // Only update the preset during drag - not the image preview
                    if (_selectedRegion == 'shadows') {
                      widget.onPresetUpdated(
                        widget.preset.copyWith(shadowsColor: newColor),
                      );
                    } else if (_selectedRegion == 'midtones') {
                      widget.onPresetUpdated(
                        widget.preset.copyWith(midtonesColor: newColor),
                      );
                    } else if (_selectedRegion == 'highlights') {
                      widget.onPresetUpdated(
                        widget.preset.copyWith(highlightsColor: newColor),
                      );
                    }
                  },
                  onPanEnd: (_) {
                    // Update the image preview only when dragging ends
                    widget.onUpdatePreview();
                    setState(() {
                      _isDraggingWheel = false;
                    });
                  },
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Intensity slider
        SliderSetting(
          label: 'Intensity',
          value: widget.tempValues['${_selectedRegion}Intensity'] ?? intensity,
          min: 0.0,
          max: 1.0,
          onChanged: onIntensityChanged,
          onChangeEnd: (value) {
            // Update the preset with the new intensity
            if (_selectedRegion == 'shadows') {
              widget.onPresetUpdated(
                widget.preset.copyWith(shadowsIntensity: value),
              );
            } else if (_selectedRegion == 'midtones') {
              widget.onPresetUpdated(
                widget.preset.copyWith(midtonesIntensity: value),
              );
            } else if (_selectedRegion == 'highlights') {
              widget.onPresetUpdated(
                widget.preset.copyWith(highlightsIntensity: value),
              );
            }
            widget.onUpdatePreview();
          },
          enabled: widget.isEditing,
        ),
      ],
    );
  }

  Widget _buildColorIndicator(Color color, double intensity) {
    // Convert color to HSV to get hue and saturation
    final HSVColor hsvColor = HSVColor.fromColor(color);

    // Calculate position on the wheel
    // Use original math functions with correct angle
    final angleRadians =
        (hsvColor.hue - 180) * math.pi / 180; // convert to radians
    final radius = hsvColor.saturation * 100; // scale to wheel radius

    // Use the standard math trigonometric functions
    // This maps 0° to right, 90° to bottom, 180° to left, 270° to top
    final x = math.cos(angleRadians) * radius;
    final y = math.sin(angleRadians) * radius;

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 3,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw color wheel with HSV model
    for (double r = 0; r < radius; r++) {
      for (double angle = 0; angle < 360; angle += 0.5) {
        final radians = angle * math.pi / 180;
        // Draw the wheel with consistent orientation
        final x = center.dx + r * math.cos(radians);
        final y = center.dy + r * math.sin(radians);

        final hue = angle;
        final saturation = r / radius;
        final color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();

        final paint =
            Paint()
              ..color = color
              ..strokeWidth = 1;

        canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
      }
    }

    // Draw outer circle border
    final borderPaint =
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(ColorWheelPainter oldDelegate) => false;
}
