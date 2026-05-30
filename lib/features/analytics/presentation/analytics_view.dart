import 'package:flutter/material.dart';
import '../../../core/services/usage_service.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  List<UsageAppModel> _usageList = [];
  Duration _totalScreenTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    final bool permitted = await _usageService.checkPermission();

    if (permitted) {
      final List<UsageAppModel> data = await _usageService.getDailyAppUsage();
      Duration total = Duration.zero;
      for (var app in data) {
        total += app.totalForegroundTime;
      }
      setState(() {
        _usageList = data;
        _totalScreenTime = total;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      );
    }

    if (_usageList.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'No analytics profile compiled. Verify usage permissions on the Dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final int totalHours = _totalScreenTime.inHours;
    final int totalMinutes = _totalScreenTime.inMinutes.remainder(60);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAnalyticsData,
        color: Theme.of(context).colorScheme.secondary,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Analytics',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Granular digital habit metrics & distributions.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),

                    // Premium Time Summary Highlight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.15),
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.timelapse_rounded,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'TOTAL SCREEN TIME TODAY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            totalHours > 0
                                ? '$totalHours\h $totalMinutes\m'
                                : '$totalMinutes\m',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'App Allocation Matrix',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Custom Proportional Distribution Graph Matrix
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final app = _usageList[index];
                  final double executionRatio =
                      _totalScreenTime.inMilliseconds > 0
                      ? (app.totalForegroundTime.inMilliseconds /
                            _totalScreenTime.inMilliseconds)
                      : 0.0;

                  final int appHours = app.totalForegroundTime.inHours;
                  final int appMinutes = app.totalForegroundTime.inMinutes
                      .remainder(60);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                app.appName, // Swapped from cleanAppName to our live system variable appName
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(executionRatio * 100).toStringAsFixed(1)}% (${appHours > 0 ? '${appHours}h ${appMinutes}m' : '${appMinutes}m'})',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // High-Performance Custom Graphical Metric Bar Slider Container
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: const Color(0xFF1B1B1F),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: executionRatio,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.secondary,
                                      Theme.of(
                                        context,
                                      ).colorScheme.secondary.withOpacity(0.5),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }, childCount: _usageList.length > 6 ? 6 : _usageList.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
