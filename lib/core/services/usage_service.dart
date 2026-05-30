import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsageAppModel {
  final String appName;
  final String packageName;
  final Duration totalForegroundTime;
  final Uint8List? iconBytes;

  UsageAppModel({
    required this.appName,
    required this.packageName,
    required this.totalForegroundTime,
    this.iconBytes,
  });
}

class CategoryUsageSummary {
  final String categoryName;
  final Duration totalDuration;
  final double percentage;

  CategoryUsageSummary({
    required this.categoryName,
    required this.totalDuration,
    required this.percentage,
  });
}

class UsageService {
  static const MethodChannel _channel = MethodChannel(
    'com.hamza.wellbeing.zenith/usage',
  );

  Future<bool> checkPermission() async =>
      await _channel.invokeMethod('checkUsagePermission');
  Future<bool> openPermissionSettings() async =>
      await _channel.invokeMethod('openPermissionSettings');
  Future<bool> checkOverlayPermission() async =>
      await _channel.invokeMethod('checkOverlayPermission');
  Future<bool> openOverlaySettings() async =>
      await _channel.invokeMethod('openOverlaySettings');
  Future<bool> syncBlockedApps(List<String> apps) async =>
      await _channel.invokeMethod('syncBlockedApps', {'apps': apps});
  Future<bool> syncAppLimits(Map<String, int> limits) async =>
      await _channel.invokeMethod('syncAppLimits', {'limits': limits});
  Future<bool> launchTargetApp(String packageName) async => await _channel
      .invokeMethod('launchTargetApp', {'packageName': packageName});

  Future<List<UsageAppModel>> getDailyAppUsage() async {
    try {
      final List<dynamic> rawData = await _channel.invokeMethod(
        'getDailyAppUsage',
      );

      return rawData.map((item) {
        final Map<dynamic, dynamic> map = item as Map<dynamic, dynamic>;
        final String pkg = map['packageName'] ?? '';
        final int ms = map['usageTime'] ?? 0;
        final String base64Icon = map['appIcon'] ?? '';

        Uint8List? decodedIcon;
        if (base64Icon.isNotEmpty) {
          try {
            // Wipe newline wrappers and trailing layout bytes if present
            final String cleanBase64 = base64Icon
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .trim();
            decodedIcon = base64Decode(cleanBase64);
          } catch (_) {}
        }

        return UsageAppModel(
          appName: map['appName'] ?? pkg.split('.').last,
          packageName: pkg,
          totalForegroundTime: Duration(milliseconds: ms),
          iconBytes: decodedIcon,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<CategoryUsageSummary> computeCategoryBreakdown(
    List<UsageAppModel> activeApps,
    Duration totalTime,
  ) {
    if (totalTime.inMinutes <= 0 || activeApps.isEmpty) return [];

    final Map<String, Duration> categoryAggregator = {
      'Social Media': Duration.zero,
      'Productivity': Duration.zero,
      'Entertainment': Duration.zero,
      'Utilities': Duration.zero,
    };

    for (var app in activeApps) {
      final String pkg = app.packageName.toLowerCase();
      String assignedCategory = 'Utilities';

      if (pkg.contains('instagram') ||
          pkg.contains('facebook') ||
          pkg.contains('twitter') ||
          pkg.contains('snapchat') ||
          pkg.contains('tiktok')) {
        assignedCategory = 'Social Media';
      } else if (pkg.contains('youtube') ||
          pkg.contains('netflix') ||
          pkg.contains('pubg') ||
          pkg.contains('game') ||
          pkg.contains('vlc')) {
        assignedCategory = 'Entertainment';
      } else if (pkg.contains('studio') ||
          pkg.contains('github') ||
          pkg.contains('flutter') ||
          pkg.contains('teams') ||
          pkg.contains('slack') ||
          pkg.contains('zoom')) {
        assignedCategory = 'Productivity';
      }

      categoryAggregator[assignedCategory] =
          categoryAggregator[assignedCategory]! + app.totalForegroundTime;
    }

    List<CategoryUsageSummary> summaries = [];
    categoryAggregator.forEach((category, duration) {
      if (duration.inMinutes > 0) {
        summaries.add(
          CategoryUsageSummary(
            categoryName: category,
            totalDuration: duration,
            percentage: duration.inMinutes / totalTime.inMinutes,
          ),
        );
      }
    });

    summaries.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
    return summaries;
  }
}
