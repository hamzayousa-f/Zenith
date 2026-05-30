import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _overlayPermitted = false;
  bool _isStrictModeActive = false;

  List<UsageAppModel> _installedApps = [];
  List<String> _blockedPackages = [];
  Map<String, int> _appLimitsMinutes = {};
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initialiseBlockerState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialiseBlockerState() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _blockedPackages = prefs.getStringList('blocked_apps') ?? [];
    _isStrictModeActive = prefs.getBool('strict_mode_active') ?? false;

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

  Future<void> _toggleStrictMode(bool value) async {
    if (!value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Strict Mode cannot be disabled manually once locked! Rules reset at midnight.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161A),
        title: const Text(
          'Activate Strict Lock?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          'This will make your block list and time limits immutable for the rest of the day. You cannot alter them to access blocked apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text(
              'Enforce Lockout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isStrictModeActive = true;
      });
      await prefs.setBool('strict_mode_active', true);
    }
  }

  Future<void> _toggleBlockStatus(String packageName) async {
    if (_isStrictModeActive) {
      _showStrictWarning();
      return;
    }

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

  void _showStrictWarning() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🔒 Strict Mode Active: Current focus rules are hard-locked.',
        ),
        backgroundColor: Color(0xFF8B5CF6),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showLimitPicker(String packageName, String appName) async {
    if (_isStrictModeActive) {
      _showStrictWarning();
      return;
    }

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
                      // Suggestion 2: Distinct physical selection click sensation
                      HapticFeedback.selectionClick();
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

    final List<UsageAppModel> filteredApps = _installedApps.where((app) {
      return app.appName.toLowerCase().contains(_searchQuery) ||
          app.packageName.toLowerCase().contains(_searchQuery);
    }).toList();

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
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isStrictModeActive
                        ? const Color(0xFF8B5CF6).withOpacity(0.08)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isStrictModeActive
                          ? const Color(0xFF8B5CF6).withOpacity(0.3)
                          : Colors.white.withOpacity(0.02),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isStrictModeActive
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: _isStrictModeActive
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Strict Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isStrictModeActive
                                  ? 'Handcuffs locked. Focus rules are immutable.'
                                  : 'Freeze adjustments until the day resets.',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isStrictModeActive,
                        activeColor: const Color(0xFF8B5CF6),
                        onChanged: (val) => _toggleStrictMode(val),
                      ),
                    ],
                  ),
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

                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search installed apps...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.01),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: filteredApps.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No matching applications found.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final app = filteredApps[index];
                    final bool isBlocked = _blockedPackages.contains(
                      app.packageName,
                    );
                    final int? activeLimit = _appLimitsMinutes[app.packageName];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface
                            .withOpacity(_isStrictModeActive ? 0.75 : 1.0),
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
                            child: GestureDetector(
                              onTap: () => _showLimitPicker(
                                app.packageName,
                                app.appName,
                              ),
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
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
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
                            onChanged: (_) =>
                                _toggleBlockStatus(app.packageName),
                          ),
                        ],
                      ),
                    );
                  }, childCount: filteredApps.length),
                ),
        ),
      ],
    );
  }
}
