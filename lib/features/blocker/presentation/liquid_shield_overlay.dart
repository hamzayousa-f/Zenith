import 'package:flutter/material.dart';

class LiquidShieldOverlay extends StatefulWidget {
  final String appName;
  final VoidCallback onDismiss;

  const LiquidShieldOverlay({
    super.key,
    required this.appName,
    required this.onDismiss,
  });

  @override
  State<LiquidShieldOverlay> createState() => _LiquidShieldOverlayState();
}

class _LiquidShieldOverlayState extends State<LiquidShieldOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _liquidController;
  int _countdown = 5;
  bool _canDismiss = false;

  @override
  void initState() {
    super.initState();

    // Top to Bottom structural slide controller
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // Fluid wavy liquid fill controller setup
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() => _canDismiss = true);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          ),
      child: Material(
        color: const Color(0xFF0D0D0F),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_rounded,
                color: Color(0xFFEF4444),
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                'Focus Rule Active: ${widget.appName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you really need to open this app?\nBreathe for 5 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 48),

              // Custom Painter Canvas to simulate the liquid glass effect
              AnimatedBuilder(
                animation: _liquidController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(160, 220),
                    painter: GlassLiquidPainter(
                      progress: _liquidController.value,
                    ),
                    child: SizedBox(
                      width: 160,
                      height: 220,
                      child: Center(
                        child: Text(
                          _canDismiss ? '✓' : '$_countdown',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 64),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canDismiss
                      ? const Color(0xFF10B981)
                      : Colors.white10,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _canDismiss ? widget.onDismiss : null,
                child: Text(
                  _canDismiss ? 'Continue Intentionally' : 'Locked',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassLiquidPainter extends CustomPainter {
  final double progress;
  GlassLiquidPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // Background structural glass outline borders
    final glassOutline = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(rrect, glassOutline);

    // Liquid fill calculation matrix paths
    final fillPath = Path();
    final fillHeight = size.height * progress;
    final topY = size.height - fillHeight;

    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, topY);

    // Add micro-curves to simulate interactive surface fluid waves
    fillPath.quadraticBezierTo(
      size.width * 0.25,
      topY - 6,
      size.width * 0.5,
      topY,
    );
    fillPath.quadraticBezierTo(size.width * 0.75, topY + 6, size.width, topY);

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(fillPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlassLiquidPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
