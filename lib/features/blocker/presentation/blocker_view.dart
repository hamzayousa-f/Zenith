import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/usage_service.dart';

class BlockerView extends StatefulWidget {
  const BlockerView({super.key});

  @override
  State<BlockerView> createState() => _BlockerViewState();
}

class _BlockerViewState extends State<BlockerView> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: BlockerViewContent());
  }
}

class BlockerViewContent extends StatefulWidget {
  const BlockerViewContent({super.key});

  @override
  State<BlockerViewContent> createState() => _BlockerViewContentState();
}

class _BlockerViewContentState extends State<BlockerViewContent> {
  final UsageService _usageService = UsageService();
  bool _isLoading = true;
  bool _overlayPermitted = false;
  List<UsageAppModel> _installedApps = [];
  List<String> _blockedPackages = [];
  Map<String, int> _appLimitsMinutes =
      {}; // Package Name vs Limit Allowance in Minutes

  @override
  void initState() {
    super.initState();
    _initialiseBlockerState();
  }

  Future<void> _initialiseBlockerState() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _blockedPackages = prefs.getStringList('blocked_apps') ?? [];

    final String savedLimitsRaw = prefs.getString('app_limits_minutes') ?? '{}';
    try {
      final Map<String, dynamic> decoded = jsonDecode(savedLimitsRaw);
      _appLimitsMinutes = decoded.map(
        (key, value) => MapEntry(key, value as int),
      );
    } catch (_) {
      _appLimitsMinutes = {};
    }

    final bool permitted = await _usageService.checkPermission();
    final bool overlayOk = await _usageService.checkOverlayPermission();

    if (permitted) {
      final List<UsageAppModel> data = await _usageService.getDailyAppUsage();
      setState(() {
        _installedApps = data;
        _overlayPermitted = overlayOk;
        _isLoading = false;
      });
      await _usageService.syncBlockedApps(_blockedPackages);
      await _usageService.syncAppLimits(_appLimitsMinutes);
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
  }

  Future<void> _showLimitPicker(String packageName, String appName) async {
    int currentSelectedValue = _appLimitsMinutes[packageName] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Daily Limit: $appName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Zenith will lock execution rules when tracking metrics pass this marker.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Allocation:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        currentSelectedValue == 0
                            ? 'No Limit'
                            : '$currentSelectedValue mins',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: currentSelectedValue.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 12,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setModalState(() => currentSelectedValue = val.toInt());
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        if (currentSelectedValue == 0) {
                          _appLimitsMinutes.remove(packageName);
                        } else {
                          _appLimitsMinutes[packageName] = currentSelectedValue;
                        }
                      });
                      await prefs.setString(
                        'app_limits_minutes',
                        jsonEncode(_appLimitsMinutes),
                      );
                      await _usageService.syncAppLimits(_appLimitsMinutes);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Save Allocation Rules',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    return CustomScrollView(
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
              final bool isBlocked = _blockedPackages.contains(app.packageName);
              final int? activeLimit = _appLimitsMinutes[app.packageName];

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
                          ? Image.memory(app.iconBytes!, width: 36, height: 36)
                          : const Icon(Icons.android, size: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showLimitPicker(app.packageName, app.appName),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.appName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeLimit == null
                                  ? 'Tap to set daily allowance'
                                  : '⏰ Cap: $activeLimit mins/day',
                              style: TextStyle(
                                color: activeLimit == null
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                fontWeight: activeLimit == null
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.av_timer_rounded,
                        color: activeLimit != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      onPressed: () =>
                          _showLimitPicker(app.packageName, app.appName),
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
    );
  }
}
