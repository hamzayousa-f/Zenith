import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/usage_service.dart';
import 'widgets/screentime_donut_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  Duration _totalScreentime = Duration.zero;
  final Duration _dailyGoal = const Duration(
    hours: 4,
  ); // Default reference threshold mark

  int _activeBlocksCount = 0;
  int _activeQuotasCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardMetrics();
  }

  Future<void> _loadDashboardMetrics() async {
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

    if (permitted) {
      final List<UsageAppModel> usageData = await _usageService
          .getDailyAppUsage();
      for (var app in usageData) {
        calculatedTotal += app.totalForegroundTime;
      }
    }

    setState(() {
      _totalScreentime = calculatedTotal;
      _activeBlocksCount = blockedApps.length;
      _activeQuotasCount = quotaCount;
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
        onRefresh: _loadDashboardMetrics,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Zenith App',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Your digital awareness hub.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),

              // Central Donut Graphic Element
              ScreentimeDonutChart(
                totalTime: _totalScreentime,
                dailyGoal: _dailyGoal,
              ),
              const SizedBox(height: 48),

              // Status Summary Title
              const Text(
                'Active Rules Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Metric Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Hard Blocks',
                      value: '$_activeBlocksCount',
                      subtitle: 'Apps fully restricted',
                      icon: Icons.gpp_maybe_outlined,
                      accentColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Time Caps',
                      value: '$_activeQuotasCount',
                      subtitle: 'Active daily limits',
                      icon: Icons.av_timer_rounded,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Tip Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.02)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Focus Tip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _totalScreentime > _dailyGoal
                                ? 'You have passed your target recommendation. Time to put down the screen!'
                                : 'Excellent pace. Keep staying intentional with your focus cycles today.',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 22),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
