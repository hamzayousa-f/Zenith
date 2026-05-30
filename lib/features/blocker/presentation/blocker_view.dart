import 'package:flutter/material.dart';
import '../../../core/services/usage_service.dart';

class BlockerView extends StatefulWidget {
  const BlockerView({super.key});

  @override
  State<BlockerView> createState() => _BlockerViewState();
}

class _BlockerViewState extends State<BlockerView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  List<UsageAppModel> _installedApps = [];

  // Local tracking map to monitor which packages have strict focus restrictions active
  final Set<String> _blockedPackages = {};

  @override
  void initState() {
    super.initState();
    _loadDeviceApps();
  }

  Future<void> _loadDeviceApps() async {
    setState(() => _isLoading = true);
    final bool permitted = await _usageService.checkPermission();

    if (permitted) {
      final List<UsageAppModel> data = await _usageService.getDailyAppUsage();
      setState(() {
        _installedApps = data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _toggleBlockStatus(String packageName) {
    setState(() {
      if (_blockedPackages.contains(packageName)) {
        _blockedPackages.remove(packageName);
      } else {
        _blockedPackages.add(packageName);
      }
    });

    // Toast feedback detailing rule insertion mutation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _blockedPackages.contains(packageName)
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
        duration: const Duration(milliseconds: 800),
        content: Text(
          _blockedPackages.contains(packageName)
              ? '🛡️ Strict restrictions applied to $packageName'
              : '🔓 Restrictions lifted successfully.',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus Blocker',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enforce strict rules over addictive applications.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Informative Guardrail Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.gpp_bad_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Aggressive Focus Shield: Active restrictions will forcefully block execution instantly during active focus blocks.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          _installedApps.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No applications discovered to build shields around.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final app = _installedApps[index];
                      final bool isCurrentlyBlocked = _blockedPackages.contains(
                        app.packageName,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrentlyBlocked
                                ? Theme.of(
                                    context,
                                  ).colorScheme.error.withOpacity(0.3)
                                : Colors.white.withOpacity(0.02),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: app.iconBytes != null
                                  ? Image.memory(
                                      app.iconBytes!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 36,
                                      height: 36,
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.android,
                                        size: 18,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.appName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    app.packageName,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Premium Minimal Toggle Switch Asset
                            Switch.adaptive(
                              value: isCurrentlyBlocked,
                              activeColor: Theme.of(context).colorScheme.error,
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.2),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (_) =>
                                  _toggleBlockStatus(app.packageName),
                            ),
                          ],
                        ),
                      );
                    }, childCount: _installedApps.length),
                  ),
                ),
        ],
      ),
    );
  }
}
