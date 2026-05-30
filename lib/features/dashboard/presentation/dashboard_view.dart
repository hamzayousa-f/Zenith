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
  int _focusScore = 100; // Psychological score ranging up to 100

  // Aesthetic color pallet tags assigned down to usage segments
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
      final activeApps = rawUsageData
          .where((app) => app.totalForegroundTime.inMinutes > 0)
          .toList();

      for (var app in activeApps) {
        calculatedTotal += app.totalForegroundTime;
      }

      // Populate Top App Lists & Segment Rings
      if (activeApps.isNotEmpty) {
        processedTopApps = activeApps.take(3).toList();

        // Take top 4 distinct apps for detailed colored slice allocation
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

        // Aggregate all lower running minor metrics into an "Others" slice
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

    // Dynamic Focus Score calculation algorithm logic
    // Subtract points heavily based on total screen hours and number of active time cap blocks
    int calculatedScore =
        100 - (calculatedTotal.inHours * 12) - (quotaCount * 4);
    if (calculatedScore < 10) calculatedScore = 10; // Floor threshold bound

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
              // Welcome Header Row
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
                  _buildFocusScoreBadge(),
                ],
              ),
              const SizedBox(height: 36),

              // Enhanced Multi-Segment Pie Graphic Element
              AppPieChart(
                segments: _pieSegments,
                totalScreentime: _totalScreentime,
              ),
              const SizedBox(height: 40),

              // Active Rules Counters Row
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

              // The Missing Piece: Today's Heavy Litmus Apps List Section
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'No prominent app usage logged today.',
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
                        // Coloured Segment Line Identifier Tracker
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
                        const SizedBox(width: 10),
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

  Widget _buildFocusScoreBadge() {
    Color conditionColor = const Color(0xFF10B981); // Green
    if (_focusScore < 75 && _focusScore >= 45)
      conditionColor = const Color(0xFFF59E0B); // Orange
    if (_focusScore < 45) conditionColor = const Color(0xFFEF4444); // Red

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: conditionColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: conditionColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$_focusScore',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: conditionColor,
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
