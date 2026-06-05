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

class _DashboardViewState extends State<DashboardView>
    with WidgetsBindingObserver {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  bool _hasPermission = false;

  Duration _totalScreentime = Duration.zero;
  List<PieSegmentData> _pieSegments = [];
  List<UsageAppModel> _topThreeApps = [];
  List<CategoryUsageSummary> _categories = [];

  int _activeBlocksCount = 0;
  int _activeQuotasCount = 0;
  int _focusScore = 100;

  bool _isDeepWorkActive = false;
  Timer? _countdownTimer;
  int _deepWorkSecondsRemaining = 1500;

  // Premium, harmonious color palette
  final List<Color> _luxuryColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF3B82F6), // Sapphire Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndLoad();
    _resumeDeepWorkSessionTimerIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndLoad();
    }
  }

  Future<void> _checkPermissionsAndLoad() async {
    final bool permitted = await _usageService.checkPermission();
    setState(() {
      _hasPermission = permitted;
    });

    if (permitted) {
      await _loadEnhancedMetrics();
    } else {
      setState(() => _isLoading = false);
    }
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

    Duration calculatedTotal = Duration.zero;
    List<PieSegmentData> computedSegments = [];
    List<UsageAppModel> processedTopApps = [];
    List<CategoryUsageSummary> computedCategories = [];

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
            color: Colors.white12,
          ),
        );
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
    HapticFeedback.lightImpact();
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
    await _usageService.syncBlockedApps(historicBlocked);
    _checkPermissionsAndLoad();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bubble_chart_rounded,
                    size: 44,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Usage Stats Needed',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Zenith requires system stats tracking data access permission to populate dashboard trends dynamically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _usageService.openPermissionSettings(),
                  child: const Text(
                    'Grant Access Permission',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int minutes = _deepWorkSecondsRemaining ~/ 60;
    final int seconds = _deepWorkSecondsRemaining % 60;
    final String timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _checkPermissionsAndLoad,
        color: const Color(0xFF6366F1),
        backgroundColor: Theme.of(context).cardColor,
        edgeOffset: 40,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24.0, 64.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zenith App',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your digital awareness hub.',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black45,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  _buildDynamicFocusBadge(isDark),
                ],
              ),
              const SizedBox(height: 32),

              // Chart Layout Wrapper
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.015)
                      : Colors.black.withOpacity(0.015),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                  ),
                ),
                child: AppPieChart(
                  segments: _pieSegments,
                  totalScreentime: _totalScreentime,
                ),
              ),
              const SizedBox(height: 24),

              // Focus Mode Session Deck Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isDeepWorkActive
                      ? const Color(0xFFEF4444).withOpacity(0.04)
                      : (isDark
                            ? Colors.white.withOpacity(0.02)
                            : Colors.black.withOpacity(0.02)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isDeepWorkActive
                        ? const Color(0xFFEF4444).withOpacity(0.25)
                        : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isDeepWorkActive)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.lens,
                                    size: 8,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              Text(
                                _isDeepWorkActive
                                    ? 'DEEP WORK ACTIVE'
                                    : 'Pomodoro Focus Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                  color: _isDeepWorkActive
                                      ? const Color(0xFFEF4444)
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isDeepWorkActive
                                ? 'All non-essential apps locked.'
                                : 'Instantly limit incoming distractions.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDeepWorkActive
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _isDeepWorkActive
                            ? _stopDeepWorkSession()
                            : _startDeepWorkSession();
                      },
                      child: Text(
                        _isDeepWorkActive ? 'Abort ($timeStr)' : 'Start 25m',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Category Breakdown Sheet
              if (_categories.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 14),
                  child: Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.015)
                        : Colors.black.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    children: List.generate(_categories.length, (idx) {
                      final cat = _categories[idx];
                      final bool isLast = idx == _categories.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 18.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat.categoryName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${cat.totalDuration.inHours > 0 ? "${cat.totalDuration.inHours}h " : ""}${cat.totalDuration.inMinutes.remainder(60)}m',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: cat.percentage,
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.black12,
                                color:
                                    _luxuryColors[idx % _luxuryColors.length],
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Top Consumers Area
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: Text(
                  'Top Time Consumers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),

              if (_topThreeApps.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.015)
                        : Colors.black.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No prominent usage logs registered yet.',
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_topThreeApps.length, (index) {
                  final app = _topThreeApps[index];
                  final Color associationColor = index < _luxuryColors.length
                      ? _luxuryColors[index]
                      : Colors.grey;
                  final int percent = _totalScreentime.inMinutes > 0
                      ? ((app.totalForegroundTime.inMinutes /
                                    _totalScreentime.inMinutes) *
                                100)
                            .toInt()
                      : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.015)
                          : Colors.black.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                app.iconBytes != null &&
                                    app.iconBytes!.isNotEmpty
                                ? Image.memory(
                                    app.iconBytes!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 6,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: associationColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            app.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${app.totalForegroundTime.inHours > 0 ? "${app.totalForegroundTime.inHours}h " : ""}${app.totalForegroundTime.inMinutes.remainder(60)}m',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

  Widget _buildDynamicFocusBadge(bool isDark) {
    double totalHours = _totalScreentime.inMinutes / 60.0;
    Color badgeColor = const Color(0xFF10B981); // Emerald
    if (totalHours > 3.0 && totalHours <= 4.0)
      badgeColor = const Color(0xFFF59E0B); // Amber
    if (totalHours > 4.0) badgeColor = const Color(0xFFEF4444); // Rose

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_focusScore',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'FOCUS INDEX',
            style: TextStyle(
              color: badgeColor.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
