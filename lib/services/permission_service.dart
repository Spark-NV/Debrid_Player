import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class PermissionService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid11OrHigher()) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          return status.isGranted;
        }
      } else {
        if (!await Permission.storage.isGranted) {
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      }
    }
    return true;
  }

  static Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 30;
    }
    return false;
  }

  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid11OrHigher()) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }
} 