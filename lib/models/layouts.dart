class Layouts {
  String name;
  List<List<int>> coordinates;
  String basePhoto;
  int id;

  Layouts({
    required this.name,
    required this.coordinates,
    required this.basePhoto,
    required this.id,
  });

  factory Layouts.fromJson(Map<String, dynamic> json) {
    return Layouts(
      name: json['name'],
      coordinates: List<List<int>>.from(
        json['coordinates'].map((coord) => List<int>.from(coord)),
      ),
      basePhoto: json['basePhoto'],
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'coordinates': coordinates.map((coord) => coord.toList()).toList(),
      'basePhoto': basePhoto,
      'id': id,
    };
  }
}
