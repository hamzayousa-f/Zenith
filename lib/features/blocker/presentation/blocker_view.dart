import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/usage_service.dart';

class BlockerView extends StatefulWidget {
  const BlockerView({super.key});

  @override
  State<BlockerView> createState() => _BlockerViewState();
}

class _BlockerViewState extends State<BlockerView> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  bool _overlayPermitted = false;
  List<UsageAppModel> _installedApps = [];
  List<String> _blockedPackages = [];

  @override
  void initState() {
    super.initState();
    _initialiseBlockerState();
  }

  Future<void> _initialiseBlockerState() async {
    setState(() => _isLoading = true);

    // Sync local preference database configurations
    final prefs = await SharedPreferences.getInstance();
    _blockedPackages = prefs.getStringList('blocked_apps') ?? [];

    final bool permitted = await _usageService.checkPermission();
    final bool overlayOk = await _usageService.checkOverlayPermission();

    if (permitted) {
      final List<UsageAppModel> data = await _usageService.getDailyAppUsage();
      setState(() {
        _installedApps = data;
        _overlayPermitted = overlayOk;
        _isLoading = false;
      });
      // Synchronize rules data vector straight over to Kotlin service threads
      await _usageService.syncBlockedApps(_blockedPackages);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlockStatus(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_blockedPackages.contains(packageName)) {
        _blockedPackages.remove(packageName);
      } else {
        _blockedPackages.add(packageName);
      }
    });

    await prefs.setStringList('blocked_apps', _blockedPackages);
    await _usageService.syncBlockedApps(_blockedPackages);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _blockedPackages.contains(packageName)
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        duration: const Duration(milliseconds: 600),
        content: Text('Focus state vector mutated for $packageName'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3)),
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
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enforce strict rules over addictive applications.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  if (!_overlayPermitted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'System Overlay permission is mandatory to display the dynamic liquid breathing shield animations over blocked apps.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                            onPressed: () async {
                              await _usageService.openOverlaySettings();
                            },
                            child: const Text('Grant Overlay Permission'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final app = _installedApps[index];
                final bool isBlocked = _blockedPackages.contains(
                  app.packageName,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
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
                              )
                            : const Icon(Icons.android, size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          app.appName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch.adaptive(
                        value: isBlocked,
                        activeColor: const Color(0xFFEF4444),
                        onChanged: (_) => _toggleBlockStatus(app.packageName),
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
