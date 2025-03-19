class Masail {
  int? id; // Nullable since SQLite will generate it
  String title;
  String description;
  String language;

  Masail({this.id, required this.title, required this.description, required this.language});

  /// Convert Masail object to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'language': language,
    };
  }

  /// Convert Map to Masail object
  factory Masail.fromMap(Map<String, dynamic> map) {
    return Masail(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()), // Convert id to int
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      language: (map['language'] ?? '').trim(),
    );
  }
}