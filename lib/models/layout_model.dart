import 'package:photobooth/models/renderables/camera_element.dart';
import 'package:photobooth/models/renderables/image_element.dart';
import 'package:photobooth/models/renderables/layout_element.dart';
import 'package:photobooth/models/renderables/text_element.dart';
import 'package:collection/collection.dart';

class LayoutModel {
  String name;
  int id;
  int width;
  int height;
  List<LayoutElement> elements;
  String backgroundColor;

  LayoutModel({
    required this.name,
    required this.id,
    required this.width,
    required this.height,
    List<LayoutElement>? elements,
    this.backgroundColor = '#FFFFFF',
  }) : elements = elements ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'width': width,
      'height': height,
      'elements': elements.map((e) => e.toJson()).toList(),
      'backgroundColor': backgroundColor,
    };
  }

  factory LayoutModel.fromJson(Map<String, dynamic> json) {
    List<LayoutElement> elementsList = [];

    if (json['elements'] != null) {
      final elements = json['elements'] as List;
      elementsList =
          elements.map((elemJson) => LayoutElement.fromJson(elemJson)).toList();
    }

    return LayoutModel(
      name: json['name'],
      id: json['id'],
      width: json['width'],
      height: json['height'],
      elements: elementsList,
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
    );
  }

  List<TextElement> get allTextElements =>
      elements.whereType<TextElement>().toList();

  List<ImageElement> get allImageElements =>
      elements.whereType<ImageElement>().toList();

  List<CameraElement> get allCameraElements =>
      elements.whereType<CameraElement>().toList();

  LayoutElement? getElementById(String id) {
    return elements.firstWhereOrNull((element) => element.id == id);
  }
}
