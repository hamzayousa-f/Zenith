import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/usage_service.dart';
import 'widgets/app_pie_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;

  Duration _totalScreentime = Duration.zero;
  List<PieSegmentData> _pieSegments = [];
  List<UsageAppModel> _topThreeApps = [];

  int _activeBlocksCount = 0;
  int _activeQuotasCount = 0;
  int _focusScore = 100;

  // Premium, high-contrast palette for the dynamic segments
  final List<Color> _luxuryColors = [
    const Color(0xFF8B5CF6), // Royal Purple
    const Color(0xFF3B82F6), // Neon Sky Blue
    const Color(0xFF10B981), // Emerald Mint
    const Color(0xFFF59E0B), // Ember Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadEnhancedMetrics();
  }

  Future<void> _loadEnhancedMetrics() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    final String savedLimitsRaw = prefs.getString('app_limits_minutes') ?? '{}';

    int quotaCount = 0;
    try {
      final Map<String, dynamic> decoded = jsonDecode(savedLimitsRaw);
      quotaCount = decoded.keys.length;
    } catch (_) {}

    final bool permitted = await _usageService.checkPermission();
    Duration calculatedTotal = Duration.zero;
    List<PieSegmentData> computedSegments = [];
    List<UsageAppModel> processedTopApps = [];

    if (permitted) {
      final List<UsageAppModel> rawUsageData = await _usageService
          .getDailyAppUsage();

      // Keep only active apps to ensure precise percentage allocation
      final activeApps = rawUsageData
          .where((app) => app.totalForegroundTime.inMinutes > 0)
          .toList();

      for (var app in activeApps) {
        calculatedTotal += app.totalForegroundTime;
      }

      if (activeApps.isNotEmpty) {
        // Track the top 3 items for the quick list section below
        processedTopApps = activeApps.take(3).toList();

        final int segmentLimit = activeApps.length > 4 ? 4 : activeApps.length;
        Duration assignedSegmentSum = Duration.zero;

        for (int i = 0; i < segmentLimit; i++) {
          final app = activeApps[i];
          assignedSegmentSum += app.totalForegroundTime;
          computedSegments.add(
            PieSegmentData(
              appName: app.appName,
              timeSpent: app.totalForegroundTime,
              color: _luxuryColors[i % _luxuryColors.length],
            ),
          );
        }

        // Collapse remaining low-priority applications into "Others"
        if (calculatedTotal > assignedSegmentSum) {
          computedSegments.add(
            PieSegmentData(
              appName: 'Others',
              timeSpent: calculatedTotal - assignedSegmentSum,
              color: Colors.white24,
            ),
          );
        }
      }
    }

    // DYNAMIC FOCUS SCORE CALCULATION ALGORITHM
    // 100 base score. Linear subtraction based on daily usage time.
    double totalHours = calculatedTotal.inMinutes / 60.0;
    int calculatedScore = 100;

    if (totalHours <= 3.0) {
      // Mild decay curve when under 3 hours
      calculatedScore = 100 - (totalHours * 5).toInt();
    } else if (totalHours > 3.0 && totalHours <= 4.0) {
      // Step down deduction between 3 to 4 hours
      calculatedScore = 85 - ((totalHours - 3.0) * 15).toInt();
    } else {
      // Drastic drop when crossing deep overuse markers (> 4 hours)
      calculatedScore = 70 - ((totalHours - 4.0) * 8).toInt();
    }

    // Absolute boundary clamps
    if (calculatedScore > 100) calculatedScore = 100;
    if (calculatedScore < 5) calculatedScore = 5;

    setState(() {
      _totalScreentime = calculatedTotal;
      _pieSegments = computedSegments;
      _topThreeApps = processedTopApps;
      _activeBlocksCount = blockedApps.length;
      _activeQuotasCount = quotaCount;
      _focusScore = calculatedScore;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadEnhancedMetrics,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zenith App',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your digital awareness hub.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  _buildDynamicFocusBadge(),
                ],
              ),
              const SizedBox(height: 36),

              AppPieChart(
                segments: _pieSegments,
                totalScreentime: _totalScreentime,
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricMiniCard(
                      title: 'Shields Up',
                      value: '$_activeBlocksCount apps',
                      icon: Icons.gpp_maybe_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricMiniCard(
                      title: 'Active Caps',
                      value: '$_activeQuotasCount rules',
                      icon: Icons.av_timer_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'Top Time Consumers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              if (_topThreeApps.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'No prominent usage logs registered yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ...List.generate(_topThreeApps.length, (index) {
                  final app = _topThreeApps[index];
                  final Color associationColor = index < _luxuryColors.length
                      ? _luxuryColors[index]
                      : Colors.white30;
                  final int percent = _totalScreentime.inMinutes > 0
                      ? ((app.totalForegroundTime.inMinutes /
                                    _totalScreentime.inMinutes) *
                                100)
                            .toInt()
                      : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: associationColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            app.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${app.totalForegroundTime.inHours > 0 ? "${app.totalForegroundTime.inHours}h " : ""}${app.totalForegroundTime.inMinutes.remainder(60)}m',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicFocusBadge() {
    double totalHours = _totalScreentime.inMinutes / 60.0;

    Color badgeColor = const Color(0xFF10B981); // Default Green under 3 hours
    if (totalHours > 3.0 && totalHours <= 4.0) {
      badgeColor = const Color(0xFFF59E0B); // Adaptive Warning Yellow/Orange
    } else if (totalHours > 4.0) {
      badgeColor = const Color(
        0xFFEF4444,
      ); // Critical Overuse Red (e.g. 8-hour marker)
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$_focusScore',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
          const Text(
            'Focus Index',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.01)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
