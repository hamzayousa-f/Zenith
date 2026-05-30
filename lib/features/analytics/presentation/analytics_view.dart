import 'package:flutter/material.dart';
import '../../../core/services/usage_service.dart';
import 'widgets/usage_bar_chart.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  List<UsageAppModel> _rankedUsageList = [];
  Duration _maxUsageTracked = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchHistoricalUsageMetrics();
  }

  Future<void> _fetchHistoricalUsageMetrics() async {
    setState(() => _isLoading = true);

    final bool permitted = await _usageService.checkPermission();
    if (permitted) {
      final List<UsageAppModel> data = await _usageService.getDailyAppUsage();

      // Filter out apps with zero screentime to keep layout pristine
      final activeApps = data
          .where((app) => app.totalForegroundTime.inMinutes > 0)
          .toList();

      setState(() {
        _rankedUsageList = activeApps;
        // The first index contains the maximum usage since the list is pre-sorted from native channel code
        _maxUsageTracked = activeApps.isNotEmpty
            ? activeApps.first.totalForegroundTime
            : Duration.zero;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchHistoricalUsageMetrics,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screentime Analytics',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detailed insight into daily behavioral usage metrics.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),

                    if (_rankedUsageList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.white24,
                              size: 44,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No Active Stats Logged Yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white60,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Metrics update naturally as you run external mobile applications.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_rankedUsageList.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final app = _rankedUsageList[index];
                    return UsageBarChart(
                      label: app.appName,
                      timeSpent: app.totalForegroundTime,
                      maxTime: _maxUsageTracked,
                      appIcon: app.iconBytes != null
                          ? MemoryImage(app.iconBytes!)
                          : null,
                    );
                  }, childCount: _rankedUsageList.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
