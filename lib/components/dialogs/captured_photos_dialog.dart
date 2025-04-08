import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CapturedPhotosDialog extends StatefulWidget {
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
  // Add a random timestamp to ensure all images are refreshed on build
  final String _buildTimestamp =
      DateTime.now().millisecondsSinceEpoch.toString();

  void _handleConfirm() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing) return false;

        widget.onCancel();
        return true;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (keyEvent) {
          if (_isProcessing) return;

          if (keyEvent is KeyDownEvent &&
              (keyEvent.logicalKey == LogicalKeyboardKey.enter ||
                  keyEvent.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _handleConfirm();
          } else if (keyEvent is KeyDownEvent &&
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
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isProcessing ? null : widget.onCancel,
                ),
                actions: [
                  TextButton(
                    onPressed: _isProcessing ? null : widget.onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _handleConfirm,
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
                    childAspectRatio: 1.0,
                  ),
                  shrinkWrap: true,
                  itemCount: widget.photos.length,
                  itemBuilder: (context, index) {
                    final photo = widget.photos[index];
                    final imageKey = ValueKey(
                      '${photo.path}?t=$_buildTimestamp-$index',
                    );

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 3.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: FutureBuilder(
                              future: photo.lastModified(),
                              builder: (context, snapshot) {
                                final modTime =
                                    snapshot.data?.millisecondsSinceEpoch ?? 0;
                                return Image.file(
                                  photo,
                                  key: ValueKey(
                                    '${photo.path}?t=$_buildTimestamp-$modTime',
                                  ),
                                  fit: BoxFit.cover,
                                  cacheHeight: null,
                                  cacheWidth: null,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.red,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
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
                          if (!_isProcessing)
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
            ],
          ),
        ),
      ),
    );
  }
}
