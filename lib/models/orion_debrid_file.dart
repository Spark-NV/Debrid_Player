enum OrionFileCategory {
  video,
  subtitle,
  other
}

class OrionDebridFile {
  final String name;
  final String link;
  final String type;
  final String extension;
  final OrionFileCategory category;
  final int size;

  OrionDebridFile({
    required this.name,
    required this.link,
    required this.type,
    required this.extension,
    required this.category,
    required this.size,
  });

  factory OrionDebridFile.fromJson(Map<String, dynamic> json) {
    OrionFileCategory category;
    switch(json['category']) {
      case 'video':
        category = OrionFileCategory.video;
      case 'subtitle':
        category = OrionFileCategory.subtitle;
      default:
        category = OrionFileCategory.other;
    }

    return OrionDebridFile(
      name: json['name'] ?? '',
      link: json['link'] ?? '',
      type: json['type'] ?? '',
      extension: json['extension'] ?? '',
      category: category,
      size: json['size'] ?? 0,
    );
  }
} 