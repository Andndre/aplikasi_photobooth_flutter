
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
      case 'group':
        return GroupElement.fromJson(json);
      default:
        throw Exception('Unknown element type: $type');
    }
  }
}

class ImageElement extends LayoutElement {
  String path;
  double opacity;
  bool aspectRatioLocked; // Add this new property

  ImageElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.path,
    this.opacity = 1.0,
    this.aspectRatioLocked =
        true, // Default to true for preserving aspect ratio
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(
         type: 'image',
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
      'aspectRatioLocked': aspectRatioLocked,
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
      aspectRatioLocked:
          json['aspectRatioLocked'] as bool? ?? true, // Default to true
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
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.text,
    this.fontFamily = 'Arial',
    this.fontSize = 24.0,
    this.color = '#000000',
    this.backgroundColor = 'transparent',
    this.isBold = false,
    this.isItalic = false,
    this.alignment = 'topLeft', // Changed from 'center' to 'topLeft'
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(type: 'text');

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
      alignment:
          json['alignment'] as String? ?? 'topLeft', // Changed default here too
    );
  }
}

class CameraElement extends LayoutElement {
  String label;

  CameraElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.label = 'Photo Spot',
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(
         type: 'camera',
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

class GroupElement extends LayoutElement {
  List<String> childIds; // IDs of child elements in this group
  String name;

  GroupElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.childIds,
    this.name = 'Group',
    super.rotation,
    super.isVisible,
    super.isLocked,
  }) : super(
         type: 'group',
       );

  factory GroupElement.fromJson(Map<String, dynamic> json) {
    return GroupElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      childIds: List<String>.from(json['childIds'] as List),
      name: json['name'] as String? ?? 'Group',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    // Create a new map instead of using super.toJson() to avoid potential recursion
    final Map<String, dynamic> json = {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isVisible': isVisible,
      'isLocked': isLocked,
      // Add group-specific properties
      'childIds': childIds,
      'name': name,
    };

    return json;
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
