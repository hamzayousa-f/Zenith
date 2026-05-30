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
      return await _channel.invokeMethod('checkUsagePermission');
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (_) {}
  }

  Future<bool> checkOverlayPermission() async {
    try {
      return await _channel.invokeMethod('checkOverlayPermission');
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } on PlatformException catch (_) {}
  }

  Future<void> syncBlockedApps(List<String> packages) async {
    try {
      await _channel.invokeMethod('syncBlockedApps', {'apps': packages});
    } on PlatformException catch (_) {}
  }

  Future<void> syncAppLimits(Map<String, int> limits) async {
    try {
      await _channel.invokeMethod('syncAppLimits', {'limits': limits});
    } on PlatformException catch (_) {}
  }

  Future<List<UsageAppModel>> getDailyAppUsage() async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>(
        'getDailyAppUsage',
      );
      if (rawList == null || rawList.isEmpty) return [];

      final List<UsageAppModel> appsList = [];
      for (var element in rawList) {
        final Map<dynamic, dynamic> appData = element as Map<dynamic, dynamic>;
        Uint8List? decodedIcon;
        final String base64String = appData['appIcon']?.toString() ?? '';
        if (base64String.isNotEmpty) {
          try {
            decodedIcon = base64Decode(base64String);
          } catch (_) {}
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
      appsList.sort(
        (a, b) => b.totalForegroundTime.compareTo(a.totalForegroundTime),
      );
      return appsList;
    } on PlatformException catch (_) {
      return [];
    }
  }
}
