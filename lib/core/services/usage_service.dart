import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class UsageAppModel {
  final String packageName;
  final String appName;
  final Duration totalForegroundTime;
  final Uint8List? iconBytes;

  UsageAppModel({
    required this.packageName,
    required this.appName,
    required this.totalForegroundTime,
    this.iconBytes,
  });
}

class UsageService {
  static const MethodChannel _channel = MethodChannel(
    'com.hamza.wellbeing.zenith/usage',
  );

  Future<bool> checkPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'checkUsagePermission',
      );
      return hasPermission;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (_) {}
  }

  Future<List<UsageAppModel>> getDailyAppUsage() async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>(
        'getDailyAppUsage',
      );

      if (rawList == null || rawList.isEmpty) {
        return [];
      }

      final List<UsageAppModel> appsList = [];

      for (var element in rawList) {
        final Map<dynamic, dynamic> appData = element as Map<dynamic, dynamic>;

        Uint8List? decodedIcon;
        final String base64String = appData['appIcon']?.toString() ?? '';
        if (base64String.isNotEmpty) {
          try {
            decodedIcon = base64Decode(base64String);
          } catch (_) {
            decodedIcon = null;
          }
        }

        appsList.add(
          UsageAppModel(
            packageName: appData['packageName'].toString(),
            appName: appData['appName'].toString(),
            totalForegroundTime: Duration(
              milliseconds: appData['usageTime'] as int,
            ),
            iconBytes: decodedIcon,
          ),
        );
      }

      // Sort descending based on heaviest execution drains
      appsList.sort(
        (a, b) => b.totalForegroundTime.compareTo(a.totalForegroundTime),
      );
      return appsList;
    } on PlatformException catch (_) {
      return [];
    }
  }
}
