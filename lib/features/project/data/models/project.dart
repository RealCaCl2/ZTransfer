/// A shooting project — the core organisational unit of ZTransfer.
class Project {
  final String id;
  final String name;
  final String? coverPhotoPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int photoCount;

  const Project({
    required this.id,
    required this.name,
    this.coverPhotoPath,
    required this.createdAt,
    required this.updatedAt,
    this.photoCount = 0,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      coverPhotoPath: (map['coverPhotoPath'] as String?)?.let((s) => s.isEmpty ? null : s),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updatedAt'] as num?)?.toInt() ?? 0),
      photoCount: (map['photoCount'] as num?)?.toInt() ?? 0,
    );
  }

  Project copyWith({
    String? name,
    String? coverPhotoPath,
    DateTime? updatedAt,
    int? photoCount,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoCount: photoCount ?? this.photoCount,
    );
  }

  String get formattedDate {
    final d = createdAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

extension _StringExt on String {
  T? let<T>(T? Function(String) f) => f(this);
}
