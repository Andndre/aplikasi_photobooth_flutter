import 'package:flutter/material.dart';

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

class NumberPropertyRow extends StatefulWidget {
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
  State<NumberPropertyRow> createState() => _NumberPropertyRowState();
}

class _NumberPropertyRowState extends State<NumberPropertyRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Use integers for better editing experience
    final intValue = widget.value.round();
    _controller = TextEditingController(text: intValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NumberPropertyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller if value changed externally and we're not editing
    if (oldWidget.value != widget.value && !_controller.text.contains('.')) {
      final intValue = widget.value.round();

      // Remember cursor position
      final currentSelection = _controller.selection;
      final oldLength = _controller.text.length;

      // Set new text
      _controller.text = intValue.toString();

      // Try to maintain cursor position logic
      if (currentSelection.isValid) {
        final newLength = _controller.text.length;
        final offset = currentSelection.baseOffset;

        if (offset <= oldLength) {
          // Adjust offset based on length change
          final newOffset = (offset * newLength / oldLength).round().clamp(
            0,
            newLength,
          );
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: newOffset),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(widget.label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: DraggableValueField(
              controller: _controller,
              value: widget.value.round().toDouble(), // Use rounded value
              label: widget.label,
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool isEditing = false;
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Set up focus listener
    focusNode.addListener(() {
      setState(() {
        isEditing = focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  // Apply changes when editing is complete
  void _applyChanges() {
    if (!isDragging) {
      try {
        // Parse the current text as an integer
        final value = int.tryParse(widget.controller.text);
        if (value != null) {
          // Only update if value changed
          if (value != widget.value.round()) {
            widget.onChanged(value.toDouble());
          }
        } else {
          // Reset to last valid value if parsing fails
          widget.controller.text = widget.value.round().toString();
        }
      } catch (e) {
        // Reset on error
        widget.controller.text = widget.value.round().toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Middle mouse button dragging
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons == 4) {
          // 4 is middle button
          setState(() {
            startX = event.localPosition.dx;
            startValue = widget.value;
            isDragging = true;
            isShiftPressed = event.down && (event.buttons & 0x8) != 0;
          });
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (isDragging) {
          final dx = event.localPosition.dx - startX;
          bool newShiftPressed = (event.buttons & 0x8) != 0;

          if (isShiftPressed != newShiftPressed) {
            setState(() {
              isShiftPressed = newShiftPressed;
            });
          }

          // Adjustment factor based on precision mode
          double adjustmentFactor = isShiftPressed ? 0.05 : 0.5;

          if (widget.label == 'Rotation') {
            adjustmentFactor = isShiftPressed ? 0.02 : 0.2;
          } else if (startValue.abs() > 100) {
            adjustmentFactor = isShiftPressed ? 0.05 : 1.0;
          }

          // Calculate new value and round to integers
          final newValue = startValue + (dx * adjustmentFactor);
          final roundedValue = newValue.round();

          // Only update if value has changed
          if (roundedValue != int.tryParse(widget.controller.text)) {
            setState(() {
              widget.controller.text = roundedValue.toString();
            });
            widget.onChanged(roundedValue.toDouble());
          }
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
            focusNode: focusNode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            // Don't process changes while typing
            onChanged: null,
            // Only apply changes when edit is complete
            onEditingComplete: () {
              _applyChanges();
              // Keep focus but hide keyboard
              FocusScope.of(context).unfocus();
              FocusScope.of(context).requestFocus(focusNode);
            },
            onSubmitted: (_) {
              _applyChanges();
            },
            // Apply changes when focus is lost
            onTapOutside: (_) {
              _applyChanges();
              focusNode.unfocus();
            },
            // Show cursor explicitly
            showCursor: true,
            mouseCursor: SystemMouseCursors.resizeLeftRight,
          ),

          // Tooltip during dragging
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
