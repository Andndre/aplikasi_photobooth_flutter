import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Common widgets for property panels
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Divider(),
        ],
      ),
    );
  }
}

class NumberPropertyRow extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const NumberPropertyRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Create a text controller with the current value
    final controller = TextEditingController(text: value.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setState) {
                // Create state variables outside the builder function as private properties
                return DraggableValueField(
                  controller: controller,
                  value: value,
                  label: label,
                  onChanged: onChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Create a new StatefulWidget to properly track dragging state
class DraggableValueField extends StatefulWidget {
  final TextEditingController controller;
  final double value;
  final String label;
  final Function(double) onChanged;

  const DraggableValueField({
    super.key,
    required this.controller,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  State<DraggableValueField> createState() => DraggableValueFieldState();
}

class DraggableValueFieldState extends State<DraggableValueField> {
  double startX = 0;
  double startValue = 0;
  bool isDragging = false;
  bool isShiftPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Use Listener instead of GestureDetector to detect mouse buttons
      onPointerDown: (PointerDownEvent event) {
        // Check if middle button is pressed (button index 2 corresponds to middle button)
        if (event.buttons == 4) {
          // 4 is middle button
          setState(() {
            startX = event.localPosition.dx;
            startValue = widget.value;
            isDragging = true;
            // Check if shift key is pressed for precision mode
            isShiftPressed = event.down && (event.buttons & 0x8) != 0;
          });
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (isDragging) {
          // Calculate delta and apply a sensitivity factor
          final dx = event.localPosition.dx - startX;

          // Check if shift key is currently pressed
          bool newShiftPressed = (event.buttons & 0x8) != 0;
          if (isShiftPressed != newShiftPressed) {
            setState(() {
              isShiftPressed = newShiftPressed;
            });
          }

          // Determine the adjustment factor based on precision mode and value magnitude
          double adjustmentFactor;

          if (isShiftPressed) {
            // Precision mode (slow changes) with Shift key
            adjustmentFactor = 0.05; // Very fine control

            if (widget.label == 'Rotation') {
              adjustmentFactor = 0.02; // Even finer for rotation
            }
          } else {
            // Fast mode (without Shift key)
            adjustmentFactor = 0.5; // Reduced from 5.0 for better control

            if (startValue.abs() > 100) {
              adjustmentFactor = 1.0; // Reduced from 10.0
            }

            if (widget.label == 'Rotation') {
              adjustmentFactor = 0.2; // Reduced from 2.0
            }
          }

          // Calculate new value with the appropriate sensitivity
          final newValue = startValue + (dx * adjustmentFactor);

          // Optionally round to 1 decimal place for better usability
          final roundedValue = (newValue * 10).round() / 10;

          // Update the controller text and call the callback
          widget.controller.text = roundedValue.toStringAsFixed(1);
          widget.onChanged(roundedValue);
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (isDragging) {
          setState(() {
            isDragging = false;
          });
        }
      },
      child: Stack(
        children: [
          TextField(
            controller: widget.controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (text) {
              final newValue = double.tryParse(text);
              if (newValue != null) {
                widget.onChanged(newValue);
              }
            },
            mouseCursor: SystemMouseCursors.resizeLeftRight,
          ),

          // Now the tooltip will properly show when isDragging is true
          if (isDragging)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isShiftPressed
                            ? Colors.blue.withOpacity(0.7)
                            : Colors.orange.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isShiftPressed ? 'Fine' : 'Fast',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SwitchPropertyRow extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const SwitchPropertyRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class DisplayProperty extends StatelessWidget {
  final String label;
  final String value;

  const DisplayProperty({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(value),
            ),
          ),
        ],
      ),
    );
  }
}
