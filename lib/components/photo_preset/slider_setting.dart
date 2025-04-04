import 'package:flutter/material.dart';

class SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final Function(double) onChangeEnd;
  final bool enabled;
  final String? leftLabel;
  final String? rightLabel;

  const SliderSetting({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    required this.enabled,
    this.leftLabel,
    this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final disabledColor = Theme.of(context).disabledColor.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('$label:'), Text(value.toStringAsFixed(2))],
          ),
          if (leftLabel != null || rightLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (leftLabel != null)
                    Text(
                      leftLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(),
                  if (rightLabel != null)
                    Text(
                      rightLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(),
                ],
              ),
            ),
          SizedBox(
            height: 26, // Reduced height for thinner slider
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0, // Thinner track
                activeTrackColor: enabled ? primaryColor : disabledColor,
                inactiveTrackColor: (enabled ? primaryColor : disabledColor)
                    .withOpacity(0.3),
                thumbColor: enabled ? primaryColor : disabledColor,
                overlayColor: Colors.transparent, // Remove the overlay effect
                thumbShape:
                    const RoundedRectangleSliderThumbShape(), // Custom square thumb shape
                overlayShape: SliderComponentShape.noOverlay, // No overlay
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: 100,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom slider thumb shape that creates a square thumb instead of circular
class RoundedRectangleSliderThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  final double borderRadius;

  const RoundedRectangleSliderThumbShape({
    this.width = 10.0,
    this.height = 10.0,
    this.borderRadius = 2.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final rect = Rect.fromCenter(center: center, width: width, height: height);

    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    final fillPaint =
        Paint()
          ..color = sliderTheme.thumbColor!
          ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, fillPaint);
  }
}
