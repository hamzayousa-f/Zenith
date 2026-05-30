import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<CategoryUsageSummary> _categories = [];

  int _activeBlocksCount = 0;
  int _activeQuotasCount = 0;
  int _focusScore = 100;

  // Deep Work State Engine Parameters
  bool _isDeepWorkActive = false;
  Timer? _countdownTimer;
  int _deepWorkSecondsRemaining = 1500; // 25 Minutes Standard

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
    _resumeDeepWorkSessionTimerIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
    List<CategoryUsageSummary> computedCategories = [];

    if (permitted) {
      final List<UsageAppModel> rawUsageData = await _usageService
          .getDailyAppUsage();
      final activeApps = rawUsageData
          .where((app) => app.totalForegroundTime.inMinutes > 0)
          .toList();

      for (var app in activeApps) {
        calculatedTotal += app.totalForegroundTime;
      }

      if (activeApps.isNotEmpty) {
        processedTopApps = activeApps.take(3).toList();
        computedCategories = _usageService.computeCategoryBreakdown(
          activeApps,
          calculatedTotal,
        );

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

    double totalHours = calculatedTotal.inMinutes / 60.0;
    int calculatedScore = 100;
    if (totalHours <= 3.0) {
      calculatedScore = 100 - (totalHours * 5).toInt();
    } else if (totalHours > 3.0 && totalHours <= 4.0) {
      calculatedScore = 85 - ((totalHours - 3.0) * 15).toInt();
    } else {
      calculatedScore = 70 - ((totalHours - 4.0) * 8).toInt();
    }

    if (calculatedScore > 100) calculatedScore = 100;
    if (calculatedScore < 5) calculatedScore = 5;

    setState(() {
      _totalScreentime = calculatedTotal;
      _pieSegments = computedSegments;
      _topThreeApps = processedTopApps;
      _categories = computedCategories;
      _activeBlocksCount = blockedApps.length;
      _activeQuotasCount = quotaCount;
      _focusScore = calculatedScore;
      _isLoading = false;
    });
  }

  // Suggestion 4: Pomodoro Storage Session Validation
  Future<void> _resumeDeepWorkSessionTimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    _isDeepWorkActive = prefs.getBool('deep_work_active') ?? false;
    final int targetExpiryTimestamp =
        prefs.getInt('deep_work_expiry_time') ?? 0;

    if (_isDeepWorkActive) {
      final int remainingTimeSecs =
          ((targetExpiryTimestamp - DateTime.now().millisecondsSinceEpoch) /
                  1000)
              .toInt();
      if (remainingTimeSecs > 0) {
        setState(() => _deepWorkSecondsRemaining = remainingTimeSecs);
        _startCountdownEngine();
      } else {
        _stopDeepWorkSession();
      }
    }
  }

  void _startDeepWorkSession() async {
    HapticFeedback.vibrate(); // Suggestion 2: Strong confirmation snap haptic trigger
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _isDeepWorkActive = true;
      _deepWorkSecondsRemaining = 1500;
    });

    await prefs.setBool('deep_work_active', true);
    await prefs.setInt(
      'deep_work_expiry_time',
      DateTime.now().millisecondsSinceEpoch + (1500 * 1000),
    );

    // Hard-lock all parsed app packages during runtime countdown window
    final rawApps = await _usageService.getDailyAppUsage();
    final List<String> catchAllPackages = rawApps
        .map((a) => a.packageName)
        .toList();
    await _usageService.syncBlockedApps(catchAllPackages);

    _startCountdownEngine();
  }

  void _stopDeepWorkSession() async {
    final prefs = await SharedPreferences.getInstance();
    _countdownTimer?.cancel();

    setState(() {
      _isDeepWorkActive = false;
      _deepWorkSecondsRemaining = 1500;
    });

    await prefs.setBool('deep_work_active', false);
    final List<String> historicBlocked =
        prefs.getStringList('blocked_apps') ?? [];
    await _usageService.syncBlockedApps(
      historicBlocked,
    ); // Restore standard rules
    _loadEnhancedMetrics();
  }

  void _startCountdownEngine() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_deepWorkSecondsRemaining > 0) {
        setState(() => _deepWorkSecondsRemaining--);
      } else {
        _stopDeepWorkSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));

    final int minutes = _deepWorkSecondsRemaining ~/ 60;
    final int seconds = _deepWorkSecondsRemaining % 60;
    final String timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

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
              const SizedBox(height: 36),

              // Suggestion 4: Deep Work Pomodoro Card View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDeepWorkActive
                      ? const Color(0xFFEF4444).withOpacity(0.06)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isDeepWorkActive
                        ? const Color(0xFFEF4444).withOpacity(0.2)
                        : Colors.white.withOpacity(0.01),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDeepWorkActive
                              ? 'DEEP WORK FOCUS LOCKED'
                              : 'Pomodoro Focus Mode',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isDeepWorkActive
                              ? 'All communications strictly blocked.'
                              : 'Lock out all application tasks instantly.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDeepWorkActive
                            ? const Color(0xFFEF4444)
                            : Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () {
                        // Suggestion 2: Micro tactile light trigger click
                        HapticFeedback.lightImpact();
                        _isDeepWorkActive
                            ? _stopDeepWorkSession()
                            : _startDeepWorkSession();
                      },
                      child: Text(
                        _isDeepWorkActive ? 'Abort ($timeStr)' : 'Start 25m',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Suggestion 3: Categorized Horizontal Stack Bars Visualizer
              if (_categories.isNotEmpty) ...[
                const Text(
                  'Category Breakdown',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: List.generate(_categories.length, (idx) {
                      final cat = _categories[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat.categoryName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${cat.totalDuration.inHours > 0 ? "${cat.totalDuration.inHours}h " : ""}${cat.totalDuration.inMinutes.remainder(60)}m',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'JetBrains Mono',
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: cat.percentage,
                              backgroundColor: Colors.white10,
                              color: _luxuryColors[idx % _luxuryColors.length],
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                'Top Time Consumers',
                style: TextStyle(
                  fontSize: 15,
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
    Color badgeColor = const Color(0xFF10B981);
    if (totalHours > 3.0 && totalHours <= 4.0)
      badgeColor = const Color(0xFFF59E0B);
    if (totalHours > 4.0) badgeColor = const Color(0xFFEF4444);

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
}
