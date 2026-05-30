import 'package:flutter/material.dart';

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
      
      // Modern Bleeding-edge Dark Theme Schema matching master channel standards
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Premium minimalist violet focus accent
          secondary: Color(0xFF10B981), // Emerald accent for healthy stats
          surface: Color(0xFF16161A), // Clean glassmorphic container cards
          error: Color(0xFFEF4444),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0 prison9E9E9F)),
        ),
      ),
      home: const MainLayoutBridge(),
    );
  }
}

/// Central Bottom Navigation Controller Bridge 
class MainLayoutBridge extends StatefulWidget {
  const MainLayoutBridge({super.key});

  @override
  State<MainLayoutBridge> createState() => _MainLayoutBridgeState();
}

class _MainLayoutBridgeState extends State<MainLayoutBridge> {
  int _currentIndex = 0;

  // Placeholder views for our feature-first directories
  final List<Widget> _pages = [
    const Center(child: Text('📊 Dashboard Feature Layer Active', style: TextStyle(fontSize: 16, color: Colors.white70))),
    const Center(child: Text('📈 Analytics View Layer Active', style: TextStyle(fontSize: 16, color: Colors.white70))),
    const Center(child: Text('🛡️ Blocker Rules Layer Active', style: TextStyle(fontSize: 16, color: Colors.white70))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
            }
            return const TextStyle(color: Colors.grey, fontSize: 12);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF121214),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_customize_outlined),
              selectedIcon: Icon(Icons.dashboard_customize, color: Theme.of(context).colorScheme.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.primary),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: const Icon(Icons.gpp_maybe_outlined),
              selectedIcon: Icon(Icons.gpp_maybe_rounded, color: Theme.of(context).colorScheme.primary),
              label: 'Blocker',
            ),
          ],
        ),
      ),
    );
  }
}