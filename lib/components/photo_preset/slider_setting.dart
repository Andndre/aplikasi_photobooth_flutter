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
            height: 30, // Fixed height for slider
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 100,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}
