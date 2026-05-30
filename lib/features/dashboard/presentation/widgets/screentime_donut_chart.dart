import 'dart:math';
import 'package:flutter/material.dart';

class ScreentimeDonutChart extends StatelessWidget {
  final Duration totalTime;
  final Duration dailyGoal;

  const ScreentimeDonutChart({
    super.key,
    required this.totalTime,
    required this.dailyGoal,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress ratio capped at 1.0
    final double totalMinutes = totalTime.inMinutes.toDouble();
    final double goalMinutes = dailyGoal.inMinutes.toDouble();
    final double progress = goalMinutes > 0
        ? min(totalMinutes / goalMinutes, 1.0)
        : 0.0;

    final int hours = totalTime.inHours;
    final int minutes = totalTime.inMinutes.remainder(60);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: DonutChartPainter(
                progress: progress,
                primaryColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Screentime',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color backgroundColor;

  DonutChartPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 14.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Draw Background Track
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw Active Progress Arc
    final Paint progressPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double startAngle = -pi / 2; // Start directly from top center
    final double sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor;
  }
}
