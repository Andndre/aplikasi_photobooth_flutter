import 'dart:convert';

// Base class for all layout elements
abstract class LayoutElement {
  String id;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  bool isLocked;
  bool isVisible;

  LayoutElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.isLocked = false,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson();

  factory LayoutElement.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'image':
        return ImageElement.fromJson(json);
      case 'text':
        return TextElement.fromJson(json);
      case 'camera':
        return CameraElement.fromJson(json);
      default:
        throw Exception('Unknown element type: $type');
    }
  }
}

class ImageElement extends LayoutElement {
  String path;
  double opacity;

  ImageElement({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
    required this.path,
    this.opacity = 1.0,
    double rotation = 0.0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         type: 'image',
         x: x,
         y: y,
         width: width,
         height: height,
         rotation: rotation,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'path': path,
      'opacity': opacity,
    };
  }

  factory ImageElement.fromJson(Map<String, dynamic> json) {
    return ImageElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      path: json['path'] as String,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class TextElement extends LayoutElement {
  String text;
  String fontFamily;
  double fontSize;
  String color;
  String backgroundColor;
  bool isBold;
  bool isItalic;
  String alignment;

  TextElement({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
    required this.text,
    this.fontFamily = 'Arial',
    this.fontSize = 24.0,
    this.color = '#000000',
    this.backgroundColor = 'transparent',
    this.isBold = false,
    this.isItalic = false,
    this.alignment = 'center',
    double rotation = 0.0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         type: 'text',
         x: x,
         y: y,
         width: width,
         height: height,
         rotation: rotation,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'text': text,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'color': color,
      'backgroundColor': backgroundColor,
      'isBold': isBold,
      'isItalic': isItalic,
      'alignment': alignment,
    };
  }

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      text: json['text'] as String,
      fontFamily: json['fontFamily'] as String? ?? 'Arial',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      color: json['color'] as String? ?? '#000000',
      backgroundColor: json['backgroundColor'] as String? ?? 'transparent',
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      alignment: json['alignment'] as String? ?? 'center',
    );
  }
}

class CameraElement extends LayoutElement {
  String label;

  CameraElement({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
    this.label = 'Photo Spot',
    double rotation = 0.0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         type: 'camera',
         x: x,
         y: y,
         width: width,
         height: height,
         rotation: rotation,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'label': label,
    };
  }

  factory CameraElement.fromJson(Map<String, dynamic> json) {
    return CameraElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      label: json['label'] as String? ?? 'Photo Spot',
    );
  }
}

class Layouts {
  String name;
  int id;
  int width;
  int height;
  List<LayoutElement> elements;
  String backgroundColor;

  Layouts({
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

  factory Layouts.fromJson(Map<String, dynamic> json) {
    List<LayoutElement> elementsList = [];
    if (json['elements'] != null) {
      final elements = json['elements'] as List;
      elementsList =
          elements.map((elemJson) => LayoutElement.fromJson(elemJson)).toList();
    } else if (json['coordinates'] != null && json['basePhoto'] != null) {
      // Convert old format to new format
      final coordinates = json['coordinates'] as List;
      if (json['basePhoto'].isNotEmpty) {
        elementsList.add(
          ImageElement(
            id: 'background',
            x: 0,
            y: 0,
            width: json['width'].toDouble(),
            height: json['height'].toDouble(),
            path: json['basePhoto'],
          ),
        );
      }
      for (int i = 0; i < coordinates.length; i++) {
        final coord = coordinates[i];
        elementsList.add(
          CameraElement(
            id: 'camera_${i + 1}',
            x: coord[0].toDouble(),
            y: coord[1].toDouble(),
            width: coord[2].toDouble(),
            height: coord[3].toDouble(),
            label: 'Photo Spot ${i + 1}',
          ),
        );
      }
    }

    return Layouts(
      name: json['name'],
      id: json['id'],
      width: json['width'],
      height: json['height'],
      elements: elementsList,
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
    );
  }
}
