class PathsConfig {
  static const String rootPath = '/storage/emulated/0/Player_Files';
  
  static const String databaseDir = '$rootPath/database';
  static const String metadataDir = '$rootPath/metadata';
  static const String actorsDir = '$rootPath/actors';
  static const String orionDir = '$rootPath/orion';
  static const String apiKeysDir = '$rootPath/apikeys';
  
  static const String databasePath = '$databaseDir/player.db';
  static const String orionKeyPath = '$apiKeysDir/orion_keys.txt';
  static const String simklKeysPath = '$apiKeysDir/simkle_keys.txt';
  static const String apiKeysFilePath = '$apiKeysDir/tmdb_keys.txt';
} 