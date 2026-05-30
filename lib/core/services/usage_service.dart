import 'package:flutter/services.dart';

class UsageAppModel {
  final String packageName;
  final Duration totalForegroundTime;

  UsageAppModel({required this.packageName, required this.totalForegroundTime});

  // Helper utility to strip package headers into clean display names
  String get cleanAppName {
    if (!packageName.contains('.')) return packageName;
    final parts = packageName.split('.');
    if (parts.last.toLowerCase() == 'android' && parts.length > 1) {
      return parts[parts.length - 2].toUpperCase();
    }
    return parts.last.toUpperCase();
  }
}

class UsageService {
  // Must match the exact namespace channel ID we declared in MainActivity.kt
  static const MethodChannel _channel = MethodChannel(
    'com.hamza.wellbeing.zenith/usage',
  );

  /// Evaluates whether the system usage log tracking toggle is allowed
  Future<bool> checkPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'checkUsagePermission',
      );
      return hasPermission;
    } on PlatformException catch (e) {
      // Intentionally fallback to false if native invocation faces runtime drift
      return false;
    }
  }

  /// Redirects the user directly to the OS Settings system access portal
  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (e) {
      // Log trace block if required
    }
  }

  /// Pulls, maps, and sorts today's application statistics from midnight to now
  Future<List<UsageAppModel>> getDailyAppUsage() async {
    try {
      final Map<dynamic, dynamic>? rawData = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getDailyAppUsage');

      if (rawData == null || rawData.isEmpty) {
        return [];
      }

      final List<UsageAppModel> appsList = [];

      rawData.forEach((key, value) {
        appsList.add(
          UsageAppModel(
            packageName: key.toString(),
            totalForegroundTime: Duration(milliseconds: value as int),
          ),
        );
      });

      // Sort descending so the biggest time-sinks sit directly at index 0
      appsList.sort(
        (a, b) => b.totalForegroundTime.compareTo(a.totalForegroundTime),
      );

      return appsList;
    } on PlatformException catch (e) {
      return [];
    }
  }
}
