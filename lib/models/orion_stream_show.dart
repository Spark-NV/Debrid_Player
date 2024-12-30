class OrionStreamShow { 
  final String id;
  final String orionId;
  final String fileName;
  final int fileSize;
  final String quality;
  final Map<String, dynamic> rawData;

  OrionStreamShow({
    required this.id,
    required this.orionId,
    required this.fileName,
    required this.fileSize,
    required this.quality,
    required this.rawData,
  });

  factory OrionStreamShow.fromJson(Map<String, dynamic> json) {
    String showOrionId = '';
    if (json['show']?['id']?['orion'] != null) {
      showOrionId = json['episode']['id']['orion'];
    } else if (json['data']?['episode']?['id']?['orion'] != null) {
      showOrionId = json['data']['episode']['id']['orion'];
    }

    return OrionStreamShow(
      id: json['id'] ?? '',
      orionId: showOrionId,
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