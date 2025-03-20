class Layouts {
  String name;
  List<List<int>> coordinates;
  String basePhoto;
  int id;
  int width;
  int height;

  Layouts({
    required this.name,
    required this.coordinates,
    required this.basePhoto,
    required this.id,
    required this.width,
    required this.height,
  });

  factory Layouts.fromJson(Map<String, dynamic> json) {
    return Layouts(
      name: json['name'],
      coordinates: List<List<int>>.from(
        json['coordinates'].map((coord) => List<int>.from(coord)),
      ),
      basePhoto: json['basePhoto'],
      id: json['id'],
      width: json['width'] ?? 1080, // Default value for backward compatibility
      height:
          json['height'] ?? 1920, // Default value for backward compatibility
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'coordinates': coordinates.map((coord) => coord.toList()).toList(),
      'basePhoto': basePhoto,
      'id': id,
      'width': width,
      'height': height,
    };
  }
}
