import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CapturedPhotosDialog extends StatefulWidget {
  // Changed to StatefulWidget
  final List<File> photos;
  final Function(int) onRetake;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CapturedPhotosDialog({
    super.key,
    required this.photos,
    required this.onRetake,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<CapturedPhotosDialog> createState() => _CapturedPhotosDialogState();
}

class _CapturedPhotosDialogState extends State<CapturedPhotosDialog> {
  bool _isProcessing = false;

  void _handleConfirm() async {
    // Prevent multiple clicks
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Call onConfirm asynchronously
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope wraps the Dialog to handle when user presses back button or clicks outside
    return WillPopScope(
      onWillPop: () async {
        // Don't allow dismissing if processing
        if (_isProcessing) return false;

        // Call onCancel when dialog is dismissed
        widget.onCancel();
        return true;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (keyEvent) {
          // Don't process key events if processing
          if (_isProcessing) return;

          // Check for Enter key press
          if (keyEvent is KeyDownEvent &&
              (keyEvent.logicalKey == LogicalKeyboardKey.enter ||
                  keyEvent.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _handleConfirm();
          }
          // Check for Escape key press
          else if (keyEvent is KeyDownEvent &&
              keyEvent.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
          }
        },
        child: Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Captured Photos'),
                // Handle close button press with onCancel
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isProcessing ? null : widget.onCancel,
                  // Disable button when processing
                ),
                actions: [
                  TextButton(
                    onPressed: _isProcessing ? null : widget.onCancel,
                    // Disable button when processing
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _handleConfirm,
                    // Disable button when processing
                    child:
                        _isProcessing
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Processing...'),
                              ],
                            )
                            : const Text('Confirm & Generate'),
                  ),
                ],
              ),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 1.0, // Square grid cells
                  ),
                  shrinkWrap: true,
                  itemCount: widget.photos.length,
                  itemBuilder: (context, index) {
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 3.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Use AspectRatio to maintain image aspect ratio
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: Image.file(
                              widget.photos[index],
                              fit:
                                  BoxFit
                                      .cover, // Cover the space while maintaining aspect ratio
                            ),
                          ),
                          // Add a small badge with photo number
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          // Retake button as overlay - disabled when processing
                          if (!_isProcessing) // Hide retake button during processing
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => widget.onRetake(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Add a progress indicator at the bottom when processing
              if (_isProcessing)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Processing images... Please wait.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
