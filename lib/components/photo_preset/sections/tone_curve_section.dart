import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:photobooth/components/photo_preset/collapsible_section.dart';
import 'package:photobooth/models/preset_model.dart';

// Add a new class to represent a curve control point with handles
class CurvePoint {
  final Offset point;
  Offset inHandle;
  Offset outHandle;

  CurvePoint({required this.point, Offset? inHandle, Offset? outHandle})
    : inHandle = inHandle ?? point,
      outHandle = outHandle ?? point;

  // Create a copy with potential new values
  CurvePoint copyWith({Offset? point, Offset? inHandle, Offset? outHandle}) {
    return CurvePoint(
      point: point ?? this.point,
      inHandle: inHandle ?? this.inHandle,
      outHandle: outHandle ?? this.outHandle,
    );
  }

  // Move the entire point including handles by a delta
  CurvePoint moveBy(Offset delta) {
    return CurvePoint(
      point: Offset(point.dx + delta.dx, point.dy + delta.dy),
      inHandle: Offset(inHandle.dx + delta.dx, inHandle.dy + delta.dy),
      outHandle: Offset(outHandle.dx + delta.dx, outHandle.dy + delta.dy),
    );
  }
}

class ToneCurveSection extends StatefulWidget {
  final PresetModel preset;
  final bool isEditing;
  final Function(PresetModel) onPresetUpdated;
  final Function() onUpdatePreview;

  const ToneCurveSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.onPresetUpdated,
    required this.onUpdatePreview,
  });

  @override
  State<ToneCurveSection> createState() => _ToneCurveSectionState();
}

class _ToneCurveSectionState extends State<ToneCurveSection> {
  String _selectedChannel = 'rgb';
  Offset? _activeHandle;
  int? _activePointIndex;
  bool _isHandleDragging = false;
  bool _isDraggingInHandle = false;

  // New data structure to store curve points with their handles
  Map<String, List<CurvePoint>> _curvePoints = {
    'rgb': [],
    'red': [],
    'green': [],
    'blue': [],
  };

  // Storage for temporary curve points during drag
  List<CurvePoint>? _tempDragCurvePoints;

  // Default linear curve points
  static const List<Offset> _defaultLinearPoints = [
    Offset(0, 256),
    Offset(256, 0),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize curve points from preset
    _initializeCurvePoints();

    // Debug the initial points
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("Initial RGB points: ${widget.preset.rgbCurvePoints.length}");
      print("Initial RED points: ${widget.preset.redCurvePoints.length}");
      print("Initial curve points for RGB: ${_curvePoints['rgb']?.length}");
    });
  }

  @override
  void didUpdateWidget(ToneCurveSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reinitialize if preset actually changed to avoid losing handle positions
    if (oldWidget.preset != widget.preset) {
      _initializeCurvePoints();
    }
  }

  // Initialize curve points with their handles from preset data
  void _initializeCurvePoints() {
    // Konversi dari CurvePointData dalam preset ke CurvePoint untuk UI
    _curvePoints['rgb'] = _convertFromPresetCurvePoints(
      widget.preset.rgbCurvePoints,
    );
    _curvePoints['red'] = _convertFromPresetCurvePoints(
      widget.preset.redCurvePoints,
    );
    _curvePoints['green'] = _convertFromPresetCurvePoints(
      widget.preset.greenCurvePoints,
    );
    _curvePoints['blue'] = _convertFromPresetCurvePoints(
      widget.preset.blueCurvePoints,
    );
  }

  // Konversi dari CurvePointData dalam preset ke CurvePoint untuk UI
  List<CurvePoint> _convertFromPresetCurvePoints(
    List<CurvePointData> presetPoints,
  ) {
    List<CurvePoint> result = [];

    for (int i = 0; i < presetPoints.length; i++) {
      final presetPoint = presetPoints[i];

      // Untuk titik ujung (pertama dan terakhir), kita tetap berikan handle
      if (i == 0) {
        // Titik pertama: hanya outHandle yang diperlukan
        result.add(
          CurvePoint(
            point: presetPoint.point,
            inHandle:
                presetPoint
                    .point, // Tetapkan ke posisi point (tidak dapat digerakkan)
            outHandle:
                presetPoint.outHandle ??
                Offset(presetPoint.point.dx + 30, presetPoint.point.dy),
          ),
        );
      } else if (i == presetPoints.length - 1) {
        // Titik terakhir: hanya inHandle yang diperlukan
        result.add(
          CurvePoint(
            point: presetPoint.point,
            inHandle:
                presetPoint.inHandle ??
                Offset(presetPoint.point.dx - 30, presetPoint.point.dy),
            outHandle:
                presetPoint
                    .point, // Tetapkan ke posisi point (tidak dapat digerakkan)
          ),
        );
      } else {
        // Titik tengah dengan kedua handle
        result.add(
          CurvePoint(
            point: presetPoint.point,
            inHandle:
                presetPoint.inHandle ??
                Offset(presetPoint.point.dx - 30, presetPoint.point.dy),
            outHandle:
                presetPoint.outHandle ??
                Offset(presetPoint.point.dx + 30, presetPoint.point.dy),
          ),
        );
      }
    }

    return result;
  }

  // Konversi dari CurvePoint untuk UI ke CurvePointData untuk preset
  List<CurvePointData> _convertToPresetCurvePoints(
    List<CurvePoint> curvePoints,
  ) {
    List<CurvePointData> result = [];

    for (int i = 0; i < curvePoints.length; i++) {
      final uiPoint = curvePoints[i];

      if (i == 0) {
        // Titik pertama: simpan outHandle
        result.add(
          CurvePointData(
            point: uiPoint.point,
            outHandle: uiPoint.outHandle, // Simpan outHandle
          ),
        );
      } else if (i == curvePoints.length - 1) {
        // Titik terakhir: simpan inHandle
        result.add(
          CurvePointData(
            point: uiPoint.point,
            inHandle: uiPoint.inHandle, // Simpan inHandle
          ),
        );
      } else {
        // Titik tengah: simpan kedua handle
        result.add(
          CurvePointData(
            point: uiPoint.point,
            inHandle: uiPoint.inHandle,
            outHandle: uiPoint.outHandle,
          ),
        );
      }
    }

    return result;
  }

  // Convert flat list of points to CurvePoint objects with handles
  List<CurvePoint> _convertToCurvePoints(List<Offset> points) {
    List<CurvePoint> result = [];

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // First and last points don't have handles
      if (i == 0 || i == points.length - 1) {
        result.add(CurvePoint(point: point));
        continue;
      }

      // For middle points, calculate default handles
      final prevPoint = points[i - 1];
      final nextPoint = points[i + 1];

      // Calculate default handle positions if this is a brand new point
      final inHandleX = point.dx - (point.dx - prevPoint.dx) / 3;
      final outHandleX = point.dx + (nextPoint.dx - point.dx) / 3;

      result.add(
        CurvePoint(
          point: point,
          inHandle: Offset(inHandleX, point.dy),
          outHandle: Offset(outHandleX, point.dy),
        ),
      );
    }

    return result;
  }

  // Convert CurvePoint objects back to flat list of points
  List<Offset> _convertToOffsets(List<CurvePoint> curvePoints) {
    return curvePoints.map((cp) => cp.point).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: 'Tone Curve',
      initiallyExpanded: false,
      children: [
        // Channel selector and reset button in a row
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'rgb',
                    label: Text('RGB', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'red',
                    label: Text('R', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'green',
                    label: Text('G', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'blue',
                    label: Text('B', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_selectedChannel},
                onSelectionChanged:
                    widget.isEditing
                        ? (Set<String> selection) {
                          _changeChannel(selection.first);
                        }
                        : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      switch (_selectedChannel) {
                        case 'red':
                          return Colors.red.withOpacity(0.2);
                        case 'green':
                          return Colors.green.withOpacity(0.2);
                        case 'blue':
                          return Colors.blue.withOpacity(0.2);
                        default:
                          return Theme.of(context).colorScheme.primaryContainer;
                      }
                    }
                    return Colors.transparent;
                  }),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
              ),
            ),
            // Reset button
            if (widget.isEditing)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Reset Curve',
                onPressed: _resetCurrentCurve,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Tone Curve Editor
        Container(
          height: 256,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Grid lines
                CustomPaint(size: const Size(256, 256), painter: GridPainter()),

                // Curve based on selected channel
                _buildCurveForChannel(_selectedChannel),

                // Points editor (only when editing)
                if (widget.isEditing) _buildCurveEditor(_selectedChannel),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Description text
        Center(
          child: Text(
            'Adjust tone and color intensity for specific tonal ranges',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // Reset the current curve to default linear curve
  void _resetCurrentCurve() {
    final resetPoints = <Offset>[const Offset(0, 256), const Offset(256, 0)];
    final resetCurvePoints = _convertToCurvePoints(resetPoints);

    setState(() {
      _curvePoints[_selectedChannel] = resetCurvePoints;
      _tempDragCurvePoints = null;
    });

    _updatePresetCurvePoints();
  }

  // Add method to change channel with the new data structure
  void _changeChannel(String newChannel) {
    if (_selectedChannel != newChannel) {
      setState(() {
        _selectedChannel = newChannel;
        _tempDragCurvePoints = null;
        _activePointIndex = null;
        _activeHandle = null;
        _isHandleDragging = false;
      });
    }
  }

  // Modified curve building method using new data structure
  Widget _buildCurveForChannel(String channel) {
    // Use temp points during dragging if available
    final curvePoints =
        _tempDragCurvePoints != null && channel == _selectedChannel
            ? _tempDragCurvePoints!
            : _curvePoints[channel] ?? [];

    // Convert to simple points for the painter
    final points = _convertToOffsets(curvePoints);

    // Extract handle positions for the painter
    final handlePositions = _extractHandlePositions(curvePoints);

    Color curveColor;
    switch (channel) {
      case 'red':
        curveColor = Colors.red;
        break;
      case 'green':
        curveColor = Colors.green;
        break;
      case 'blue':
        curveColor = Colors.blue;
        break;
      default: // rgb
        curveColor = Colors.white;
    }

    return CustomPaint(
      size: const Size(256, 256),
      painter: CurvePainter(
        points: points,
        color: curveColor,
        thickness: 2.0,
        handlePositions: handlePositions,
      ),
    );
  }

  // Extract handle positions for the curve painter
  Map<int, Pair<Offset, Offset>> _extractHandlePositions(
    List<CurvePoint> curvePoints,
  ) {
    final result = <int, Pair<Offset, Offset>>{};

    for (int i = 1; i < curvePoints.length - 1; i++) {
      final point = curvePoints[i];
      result[i] = Pair(point.inHandle, point.outHandle);
    }

    return result;
  }

  void _handleDoubleTap(Offset position, String channel) {
    if (!widget.isEditing) return;

    // Print the position for debugging
    print('Double-tap at position: $position');

    // Ensure position is within valid range
    final validPosition = Offset(
      position.dx.clamp(0, 256),
      position.dy.clamp(0, 256),
    );

    final curvePoints = List<CurvePoint>.from(_curvePoints[channel] ?? []);
    if (curvePoints.isEmpty) {
      // Initialize with default points if empty
      curvePoints.add(CurvePoint(point: const Offset(0, 256)));
      curvePoints.add(CurvePoint(point: const Offset(256, 0)));
    }

    // Find where to insert the new point
    int insertIndex = 1; // Default after first point

    for (int i = 0; i < curvePoints.length - 1; i++) {
      if (validPosition.dx > curvePoints[i].point.dx &&
          validPosition.dx < curvePoints[i + 1].point.dx) {
        insertIndex = i + 1;
        break;
      }
    }

    // Can't add points before first or after last point
    if (insertIndex <= 0 || insertIndex >= curvePoints.length) {
      print('Cannot insert point at index $insertIndex (out of bounds)');
      return;
    }

    print('Inserting point at index $insertIndex');

    // Create new curve point with handles
    final newPoint = _createNewCurvePoint(
      validPosition,
      curvePoints,
      insertIndex,
    );
    curvePoints.insert(insertIndex, newPoint);

    // Update curve points without recalculating handles
    setState(() {
      _curvePoints[channel] = curvePoints;
    });

    // Update the preset
    _updatePresetCurvePoints();
  }

  void _handlePanDown(Offset position, String channel) {
    if (!widget.isEditing) return;

    final validPosition = Offset(
      position.dx.clamp(0, 256),
      position.dy.clamp(0, 256),
    );

    // Make sure we have curve points
    final curvePoints = _curvePoints[channel] ?? [];
    if (curvePoints.isEmpty) {
      print("No curve points available");
      return;
    }

    // First try to find a handle that was clicked
    for (int i = 0; i < curvePoints.length; i++) {
      final point = curvePoints[i];

      // Khusus untuk titik-titik ujung
      if (i == 0) {
        // Titik pertama hanya periksa outHandle
        if ((point.outHandle - validPosition).distance < 15) {
          print("Selected first point out-handle");
          setState(() {
            _activePointIndex = i;
            _activeHandle = point.outHandle;
            _isHandleDragging = true;
            _isDraggingInHandle = false; // Flag sebagai outHandle
            _tempDragCurvePoints = List<CurvePoint>.from(curvePoints);
          });
          return;
        }
      } else if (i == curvePoints.length - 1) {
        // Titik terakhir hanya periksa inHandle
        if ((point.inHandle - validPosition).distance < 15) {
          print("Selected last point in-handle");
          setState(() {
            _activePointIndex = i;
            _activeHandle = point.inHandle;
            _isHandleDragging = true;
            _isDraggingInHandle = true; // Flag sebagai inHandle
            _tempDragCurvePoints = List<CurvePoint>.from(curvePoints);
          });
          return;
        }
      } else {
        // Titik tengah periksa kedua handle
        // Check in handle
        if ((point.inHandle - validPosition).distance < 15) {
          print("Selected in-handle for point $i");
          setState(() {
            _activePointIndex = i;
            _activeHandle = point.inHandle;
            _isHandleDragging = true;
            _isDraggingInHandle = true;
            _tempDragCurvePoints = List<CurvePoint>.from(curvePoints);
          });
          return;
        }

        // Check out handle
        if ((point.outHandle - validPosition).distance < 15) {
          print("Selected out-handle for point $i");
          setState(() {
            _activePointIndex = i;
            _activeHandle = point.outHandle;
            _isHandleDragging = true;
            _isDraggingInHandle = false;
            _tempDragCurvePoints = List<CurvePoint>.from(curvePoints);
          });
          return;
        }
      }
    }

    // If we're here, we're not dragging a handle
    setState(() {
      _activeHandle = null;
      _isHandleDragging = false;
      _isDraggingInHandle = false;
    });

    // Now check if we're clicking on a control point
    int? nearestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < curvePoints.length; i++) {
      final distance = (curvePoints[i].point - validPosition).distance;
      if (distance < minDistance && distance < 20) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    if (nearestIndex != null) {
      // Don't allow dragging endpoints
      if (nearestIndex > 0 && nearestIndex < curvePoints.length - 1) {
        print("Selected control point $nearestIndex");
        setState(() {
          _activePointIndex = nearestIndex;
          _tempDragCurvePoints = List<CurvePoint>.from(curvePoints);
        });
      }
    } else {
      // Reset active point if we didn't click on anything
      _activePointIndex = null;
      print("No point selected");
    }
  }

  void _handlePanUpdate(Offset position, String channel) {
    if (!widget.isEditing || _activePointIndex == null) return;

    final validPosition = Offset(
      position.dx.clamp(0, 256),
      position.dy.clamp(0, 256),
    );

    if (_isHandleDragging) {
      // Handle dragging
      _handleHandleDrag(validPosition, channel);
    } else {
      // Point dragging
      _handlePointDrag(validPosition, channel);
    }
  }

  void _handleHandleDrag(Offset position, String channel) {
    if (_activePointIndex == null) return;

    _tempDragCurvePoints ??= List<CurvePoint>.from(_curvePoints[channel] ?? []);
    if (_tempDragCurvePoints!.isEmpty) return;

    final pointIndex = _activePointIndex!;
    if (pointIndex >= _tempDragCurvePoints!.length) return;

    final curvePoint = _tempDragCurvePoints![pointIndex];
    final point = curvePoint.point;

    // Update the appropriate handle
    setState(() {
      if (pointIndex == 0) {
        // Titik pertama: hanya outHandle yang bisa digerakkan
        if (!_isDraggingInHandle) {
          // Khusus outHandle: x harus lebih besar dari posisi titik
          final newX = math.max(position.dx, point.dx + 1);
          final newPosition = Offset(newX, position.dy);
          _activeHandle = newPosition;
          _tempDragCurvePoints![pointIndex] = curvePoint.copyWith(
            outHandle: newPosition,
          );
        }
      } else if (pointIndex == _tempDragCurvePoints!.length - 1) {
        // Titik terakhir: hanya inHandle yang bisa digerakkan
        if (_isDraggingInHandle) {
          // Khusus inHandle: x harus lebih kecil dari posisi titik
          final newX = math.min(position.dx, point.dx - 1);
          final newPosition = Offset(newX, position.dy);
          _activeHandle = newPosition;
          _tempDragCurvePoints![pointIndex] = curvePoint.copyWith(
            inHandle: newPosition,
          );
        }
      } else {
        // Titik tengah: kedua handle bisa digerakkan
        if (_isDraggingInHandle) {
          // Update in-handle (left)
          // Constrain x-coordinate to be less than the point
          final newX = math.min(position.dx, point.dx - 1);
          final newPosition = Offset(newX, position.dy);
          _activeHandle = newPosition;
          _tempDragCurvePoints![pointIndex] = curvePoint.copyWith(
            inHandle: newPosition,
          );
        } else {
          // Update out-handle (right)
          // Constrain x-coordinate to be greater than the point
          final newX = math.max(position.dx, point.dx + 1);
          final newPosition = Offset(newX, position.dy);
          _activeHandle = newPosition;
          _tempDragCurvePoints![pointIndex] = curvePoint.copyWith(
            outHandle: newPosition,
          );
        }
      }
    });

    // Cetak untuk debug
    print("Updated handle: ${_activeHandle}");
  }

  void _handlePointDrag(Offset position, String channel) {
    if (_activePointIndex == null) return;

    final curvePoints = _curvePoints[channel] ?? [];
    if (curvePoints.isEmpty) return;

    final pointIndex = _activePointIndex!;
    if (pointIndex <= 0 || pointIndex >= curvePoints.length - 1) return;

    // Ensure point stays between its neighbors
    final minX = curvePoints[pointIndex - 1].point.dx + 1;
    final maxX = curvePoints[pointIndex + 1].point.dx - 1;
    final newX = position.dx.clamp(minX, maxX);
    final newY = position.dy.clamp(0.0, 256.0);

    _tempDragCurvePoints ??= List<CurvePoint>.from(curvePoints);

    final oldPoint = _tempDragCurvePoints![pointIndex].point;
    final delta = Offset(newX - oldPoint.dx, newY - oldPoint.dy);

    // Move the point and its handles by the same delta
    setState(() {
      _tempDragCurvePoints![pointIndex] = _tempDragCurvePoints![pointIndex]
          .moveBy(delta);
    });
  }

  void _handlePanEnd(String channel) {
    if (_tempDragCurvePoints != null) {
      // Buat salinan dalam untuk memastikan perubahan handle disimpan
      final updatedCurvePoints = List<CurvePoint>.from(_tempDragCurvePoints!);

      // Simpan ke points map
      setState(() {
        _curvePoints[channel] = updatedCurvePoints;
        _tempDragCurvePoints = null;
      });

      print("Saved points after drag: ${updatedCurvePoints.length}");
      // Cetak posisi handle untuk debugging
      if (updatedCurvePoints.length >= 2) {
        print("Point 0 outHandle: ${updatedCurvePoints[0].outHandle}");
        print("Point 1 inHandle: ${updatedCurvePoints[1].inHandle}");
      }

      // Update preset hanya SETELAH kita simpan perubahan
      _updatePresetCurvePoints();
    }

    setState(() {
      _activePointIndex = null;
      _activeHandle = null;
      _isHandleDragging = false;
    });
  }

  // Update preset with the current curve points
  void _updatePresetCurvePoints() {
    // Konversi CurvePoint ke CurvePointData untuk disimpan dalam preset
    final rgbPoints = _convertToPresetCurvePoints(_curvePoints['rgb'] ?? []);
    final redPoints = _convertToPresetCurvePoints(_curvePoints['red'] ?? []);
    final greenPoints = _convertToPresetCurvePoints(
      _curvePoints['green'] ?? [],
    );
    final bluePoints = _convertToPresetCurvePoints(_curvePoints['blue'] ?? []);

    // Update the preset
    widget.onPresetUpdated(
      widget.preset.copyWith(
        rgbCurvePoints: rgbPoints,
        redCurvePoints: redPoints,
        greenCurvePoints: greenPoints,
        blueCurvePoints: bluePoints,
      ),
    );

    // Update preview
    widget.onUpdatePreview();
  }

  // Method to create initial handles for a new point
  CurvePoint _createNewCurvePoint(
    Offset pointPosition,
    List<CurvePoint> curvePoints,
    int insertIndex,
  ) {
    final prevPoint = curvePoints[insertIndex - 1].point;
    final nextPoint =
        curvePoints[insertIndex]
            .point; // This is the current point at insertIndex that will be shifted

    // Calculate default handle positions
    final inHandleX = pointPosition.dx - (pointPosition.dx - prevPoint.dx) / 3;
    final outHandleX = pointPosition.dx + (nextPoint.dx - pointPosition.dx) / 3;

    return CurvePoint(
      point: pointPosition,
      inHandle: Offset(inHandleX, pointPosition.dy),
      outHandle: Offset(outHandleX, pointPosition.dy),
    );
  }

  // Modified curve editor using the new data structure
  Widget _buildCurveEditor(String channel) {
    final curvePoints = _tempDragCurvePoints ?? _curvePoints[channel] ?? [];

    return SizedBox(
      width: 256,
      height: 256,
      child: GestureDetector(
        behavior:
            HitTestBehavior.opaque, // Important: make entire area responsive
        onDoubleTapDown: (details) {
          if (widget.isEditing) {
            _handleDoubleTap(details.localPosition, channel);
          }
        },
        onPanDown: (details) {
          if (widget.isEditing) {
            _handlePanDown(details.localPosition, channel);
          }
        },
        onPanUpdate: (details) {
          if (widget.isEditing) {
            _handlePanUpdate(details.localPosition, channel);
          }
        },
        onPanEnd: (details) {
          if (widget.isEditing) {
            _handlePanEnd(channel);
          }
        },
        child: Stack(
          children: [
            // Points visualization (draw under the finger)
            ...curvePoints.map(
              (curvePoint) => Positioned(
                left: curvePoint.point.dx - 6,
                top: curvePoint.point.dy - 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getChannelColor(channel),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),

            // Visualisasi handle untuk semua titik (termasuk ujung)
            if (widget.isEditing)
              ...List.generate(curvePoints.length, (i) {
                final curvePoint = curvePoints[i];
                final isActive = _activePointIndex == i;
                final widgets = <Widget>[];

                // Container untuk garis handle
                widgets.add(
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HandleLinePainter(
                        curvePoint.point,
                        i == 0
                            ? [curvePoint.outHandle]
                            : i == curvePoints.length - 1
                            ? [curvePoint.inHandle]
                            : [curvePoint.inHandle, curvePoint.outHandle],
                        _getChannelColor(channel).withOpacity(0.6),
                      ),
                    ),
                  ),
                );

                // Helper function to build handle
                Widget buildHandle(Offset position, bool isInHandle) {
                  final isActiveHandle =
                      isActive &&
                      ((isInHandle && _isDraggingInHandle) ||
                          (!isInHandle &&
                              !_isDraggingInHandle &&
                              _isHandleDragging));

                  return Positioned(
                    left: position.dx - 4,
                    top: position.dy - 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            isActiveHandle
                                ? Colors.yellow.withOpacity(0.9)
                                : Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getChannelColor(channel).withOpacity(0.8),
                          width: isActiveHandle ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }

                // Visualisasi handle sesuai posisi titik
                if (i == 0) {
                  // Titik pertama: hanya visualisasi outHandle
                  widgets.add(buildHandle(curvePoint.outHandle, false));
                } else if (i == curvePoints.length - 1) {
                  // Titik terakhir: hanya visualisasi inHandle
                  widgets.add(buildHandle(curvePoint.inHandle, true));
                } else {
                  // Titik tengah: visualisasi kedua handle
                  widgets.add(buildHandle(curvePoint.inHandle, true));
                  widgets.add(buildHandle(curvePoint.outHandle, false));
                }

                return widgets;
              }).expand((widgets) => widgets).toList(),
          ],
        ),
      ),
    );
  }

  // Add the missing _getChannelColor method
  Color _getChannelColor(String channel) {
    switch (channel) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.white;
    }
  }
}

// Simple Pair class to hold two values
class Pair<T, U> {
  final T first;
  final U second;

  Pair(this.first, this.second);
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..strokeWidth = 0.5;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final position = i * (size.width / 4);

      // Horizontal lines
      canvas.drawLine(Offset(0, position), Offset(size.width, position), paint);

      // Vertical lines
      canvas.drawLine(
        Offset(position, 0),
        Offset(position, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CurvePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double thickness;
  final Map<int, Pair<Offset, Offset>>? handlePositions;

  CurvePainter({
    required this.points,
    required this.color,
    this.thickness = 2.0,
    this.handlePositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = thickness
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // Draw curve by connecting points
    if (points.length == 2) {
      // Just draw a straight line
      canvas.drawLine(points[0], points[1], paint);
    } else {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];

        if (i > 0 && i < points.length - 2 && handlePositions != null) {
          // Use custom handles if available
          final handles = handlePositions![i];
          if (handles != null) {
            // Use actual handle positions for better curve control
            final outHandle = handles.second; // Out handle from current point
            final nextInHandle =
                handlePositions![i + 1]?.first; // In handle from next point

            if (nextInHandle != null) {
              // Use both handles for precise curve control
              path.cubicTo(
                outHandle.dx,
                outHandle.dy,
                nextInHandle.dx,
                nextInHandle.dy,
                p2.dx,
                p2.dy,
              );
            } else {
              // Fallback if next in handle is not available
              path.cubicTo(
                outHandle.dx,
                outHandle.dy,
                p2.dx - (p2.dx - p1.dx) / 3,
                p2.dy,
                p2.dx,
                p2.dy,
              );
            }
          } else {
            // Fallback to calculated controls if handles not available
            final cps = _calculateCurveControlPoints(
              points[i - 1],
              points[i],
              points[i + 1],
              points[i + 2],
            );
            path.cubicTo(
              cps.first.dx,
              cps.first.dy,
              cps.second.dx,
              cps.second.dy,
              p2.dx,
              p2.dy,
            );
          }
        } else {
          // Simple cubic interpolation for endpoints
          path.cubicTo(
            p1.dx + (p2.dx - p1.dx) / 3,
            p1.dy,
            p2.dx - (p2.dx - p1.dx) / 3,
            p2.dy,
            p2.dx,
            p2.dy,
          );
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  // Helper method to calculate better control points for smooth curves
  Pair<Offset, Offset> _calculateCurveControlPoints(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
  ) {
    // Calculate tension factor
    final tension = 0.5;

    // Calculate control points
    final dx1 = p1.dx + (p2.dx - p0.dx) * tension;
    final dy1 = p1.dy + (p2.dy - p0.dy) * tension;

    final dx2 = p2.dx - (p3.dx - p1.dx) * tension;
    final dy2 = p2.dy - (p3.dy - p1.dy) * tension;

    return Pair(Offset(dx1, dy1), Offset(dx2, dy2));
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.thickness != thickness;
  }
}

// Painter for handle lines
class HandleLinePainter extends CustomPainter {
  final Offset point;
  final List<Offset> handles;
  final Color color;

  HandleLinePainter(this.point, this.handles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    for (var handle in handles) {
      canvas.drawLine(point, handle, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
