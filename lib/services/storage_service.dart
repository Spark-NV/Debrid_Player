import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import '../config/paths_config.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class StorageService {
  StorageService._privateConstructor();
  static final StorageService instance = StorageService._privateConstructor();

  Future<String> get _metadataPath async {
    await Directory(PathsConfig.metadataDir).create(recursive: true);
    return PathsConfig.metadataDir;
  }

  Future<void> saveMetadata(String tmdbId, Map<String, dynamic> metadata) async {
    final path = await _metadataPath;
    final itemDir = Directory('$path/$tmdbId');
    await itemDir.create(recursive: true);

    final file = File('${itemDir.path}/metadata.json');
    await file.writeAsString(json.encode(metadata));
  }

  Future<void> savePoster(String tmdbId, List<int> imageBytes) async {
    final path = await _metadataPath;
    final itemDir = Directory('$path/$tmdbId');
    await itemDir.create(recursive: true);

    final file = File('${itemDir.path}/poster.jpg');
    await file.writeAsBytes(imageBytes);
  }

  Future<Map<String, dynamic>?> getMetadata(String tmdbId) async {
    final path = await _metadataPath;
    final file = File('$path/$tmdbId/metadata.json');
    
    if (await file.exists()) {
      final content = await file.readAsString();
      return json.decode(content);
    }
    return null;
  }

  Future<File?> getPosterFile(String tmdbId) async {
    final path = await _metadataPath;
    final file = File('$path/$tmdbId/poster.jpg');
    
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<String> getActorImagePath(int actorId) async {
    await Directory(PathsConfig.actorsDir).create(recursive: true);
    return '${PathsConfig.actorsDir}/$actorId.jpg';
  }

  Future<File?> getActorImageFile(int actorId) async {
    final path = await getActorImagePath(actorId);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> saveActorImage(int actorId, Uint8List imageBytes) async {
    final path = await getActorImagePath(actorId);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }
} 