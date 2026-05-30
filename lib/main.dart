import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/dashboard/presentation/dashboard_view.dart';
import 'features/analytics/presentation/analytics_view.dart';
import 'features/blocker/presentation/blocker_view.dart';
import 'features/blocker/presentation/liquid_shield_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZenithApp());
}

class ZenithApp extends StatelessWidget {
  const ZenithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenith',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF16161A),
          error: Color(0xFFEF4444),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: Color(0xFF9E9E9F),
          ),
        ),
      ),
      home: const MainLayoutBridge(),
    );
  }
}

class MainLayoutBridge extends StatefulWidget {
  const MainLayoutBridge({super.key});

  @override
  State<MainLayoutBridge> createState() => _MainLayoutBridgeState();
}

class _MainLayoutBridgeState extends State<MainLayoutBridge> {
  int _currentIndex = 0;
  static const _channel = MethodChannel('com.hamza.wellbeing.zenith/usage');

  String? _interceptedApp;
  bool _isShieldActive = false;

  final List<Widget> _pages = [
    const DashboardView(),
    const AnalyticsView(),
    const BlockerView(),
  ];

  @override
  void initState() {
    super.initState();
    // Establish real-time tracking pipelines for platform mutations
    _channel.setMethodCallHandler((call) async {
      if (call.method == "triggerNativeShield") {
        final String appLabel = call.arguments.toString();
        _activateShield(appLabel);
      }
    });
  }

  void _activateShield(String appLabel) {
    if (_isShieldActive) return;
    setState(() {
      _interceptedApp = appLabel;
      _isShieldActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(child: _pages[_currentIndex]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) =>
                setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF121214),
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_customize_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.gpp_maybe_outlined),
                label: 'Blocker',
              ),
            ],
          ),
        ),

        // Render Liquid Shading Canvas directly over layout frameworks dynamically
        if (_isShieldActive && _interceptedApp != null)
          Positioned.fill(
            child: LiquidShieldOverlay(
              appName: _interceptedApp!,
              onDismiss: () {
                setState(() {
                  _isShieldActive = false;
                  _interceptedApp = null;
                });
                // Minimize back to hardware home paths safely
                SystemNavigator.pop();
              },
            ),
          ),
      ],
    );
  }
}
