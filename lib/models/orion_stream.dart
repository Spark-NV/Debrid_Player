class OrionStream {
  final String id;
  final String orionId;
  final String fileName;
  final int fileSize;
  final String quality;
  final Map<String, dynamic> rawData;

  OrionStream({
    required this.id,
    required this.orionId,
    required this.fileName,
    required this.fileSize,
    required this.quality,
    required this.rawData,
  });

  factory OrionStream.fromJson(Map<String, dynamic> json) {
    String movieOrionId = '';
    if (json['movie']?['id']?['orion'] != null) {
      movieOrionId = json['movie']['id']['orion'];
    } else if (json['data']?['movie']?['id']?['orion'] != null) {
      movieOrionId = json['data']['movie']['id']['orion'];
    }

    return OrionStream(
      id: json['id'] ?? '',
      orionId: movieOrionId,
      fileName: json['file']?['name'] ?? 'Unknown',
      fileSize: json['file']?['size'] ?? 0,
      quality: json['video']?['quality'] ?? 'unknown',
      rawData: json,
    );
  }

  String get formattedSize {
    final sizeInGb = fileSize / 1024 / 1024 / 1024;
    return '${sizeInGb.toStringAsFixed(2)} GB';
  }
} 