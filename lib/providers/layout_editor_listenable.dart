import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/layouts.dart';

// Create a value notifier that only updates when the selected element changes
class SelectedElementNotifier extends ValueNotifier<LayoutElement?> {
  SelectedElementNotifier() : super(null);

  void selectElement(LayoutElement? element) {
    value = element;
  }
}

// Create a value notifier for zoom level
class ZoomLevelNotifier extends ValueNotifier<double> {
  ZoomLevelNotifier() : super(1.0);

  void setZoom(double zoom) {
    value = zoom.clamp(0.1, 5.0);
  }
}
