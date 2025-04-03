import 'package:flutter/material.dart';
import 'package:photobooth/providers/sesi_foto.dart';
import 'package:photobooth/services/screen_capture_service.dart';

// Widget for the window selection dropdown
class WindowSelectionDropdown extends StatefulWidget {
  final SesiFotoProvider provider;

  const WindowSelectionDropdown({super.key, required this.provider});

  @override
  WindowSelectionDropdownState createState() => WindowSelectionDropdownState();
}

class WindowSelectionDropdownState extends State<WindowSelectionDropdown> {
  List<WindowInfo> _availableWindows = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableWindows();
  }

  // Gunakan metode dari service untuk mendapat daftar window
  void _loadAvailableWindows() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Gunakan fungsi dari service
      final windows = await ScreenCaptureService.getWindowsList();

      // Add a slight delay to ensure UI updates properly
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _availableWindows = windows;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading windows: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Ensure we have at least one window available
          if (_availableWindows.isEmpty) {
            _availableWindows = [
              WindowInfo(hwnd: 0, title: 'No windows found'),
            ];
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWindow = widget.provider.windowToCapture;
    final captureMethod = widget.provider.captureMethod;

    return Badge(
      isLabelVisible: currentWindow == null,
      backgroundColor: Theme.of(context).colorScheme.error,
      smallSize: 8,
      child: PopupMenuButton(
        icon: const Icon(Icons.settings),
        tooltip:
            currentWindow == null
                ? 'Select a window to capture'
                : 'Capture Settings',
        position: PopupMenuPosition.under,
        // Refresh window list when menu is opened
        onOpened: _loadAvailableWindows,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          minWidth: 300,
        ),
        itemBuilder:
            (context) => [
              PopupMenuItem(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Window Selection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child:
                                  _isLoading
                                      ? const Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : DropdownButton<int>(
                                        value: currentWindow?.hwnd,
                                        isExpanded: true,
                                        onChanged: (int? newValue) {
                                          if (newValue != null) {
                                            if (newValue == 0) {
                                              widget.provider
                                                  .setWindowToCapture(null);
                                            } else {
                                              final selectedWindow =
                                                  _availableWindows.firstWhere(
                                                    (window) =>
                                                        window.hwnd == newValue,
                                                    orElse:
                                                        () =>
                                                            _availableWindows
                                                                .first,
                                                  );

                                              if (selectedWindow.hwnd != 0) {
                                                widget.provider
                                                    .setWindowToCapture(
                                                      selectedWindow,
                                                    );
                                              } else {
                                                widget.provider
                                                    .setWindowToCapture(null);
                                              }
                                            }
                                          }
                                          Navigator.pop(context);
                                        },
                                        items:
                                            _availableWindows
                                                .map<DropdownMenuItem<int>>((
                                                  window,
                                                ) {
                                                  return DropdownMenuItem<int>(
                                                    value: window.hwnd,
                                                    child: Text(
                                                      window.title,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                      ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () {
                                _loadAvailableWindows();
                              },
                            ),
                          ],
                        ),

                        const Divider(),
                        const Text(
                          'Performance Settings',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Extreme Power Saving:"),
                            Switch(
                              value: widget.provider.extremeOptimizationMode,
                              onChanged: (value) {
                                widget.provider.toggleExtremeOptimizationMode();
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Capture Method: (Auto-selected based on window type)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCaptureMethodName(captureMethod),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
      ),
    );
  }

  // Helper method to get the name of the capture method
  String _getCaptureMethodName(CaptureMethod method) {
    switch (method) {
      case CaptureMethod.standard:
        return 'Standard (BitBlt/PrintWindow)';
      case CaptureMethod.printWindow:
        return 'PrintWindow (Better Compatibility)';
      case CaptureMethod.fullscreen:
        return 'Fullscreen/Browser Mode';
    }
  }
}
