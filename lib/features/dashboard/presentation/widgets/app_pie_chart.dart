import 'dart:math';
import 'package:flutter/material.dart';

class PieSegmentData {
  final String appName;
  final Duration timeSpent;
  final Color color;

  PieSegmentData({
    required this.appName,
    required this.timeSpent,
    required this.color,
  });
}

class AppPieChart extends StatelessWidget {
  final List<PieSegmentData> segments;
  final Duration totalScreentime;

  const AppPieChart({
    super.key,
    required this.segments,
    required this.totalScreentime,
  });

  @override
  Widget build(BuildContext context) {
    final int hours = totalScreentime.inHours;
    final int minutes = totalScreentime.inMinutes.remainder(60);
    final String centralText = hours > 0
        ? '${hours}h ${minutes}m'
        : '${minutes}m';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: MultiSegmentPiePainter(
                segments: segments,
                totalMinutes: totalScreentime.inMinutes.toDouble(),
                trackColor: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          // Central Ring Text HUD
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centralText,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Today Total',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MultiSegmentPiePainter extends CustomPainter {
  final List<PieSegmentData> segments;
  final double totalMinutes;
  final Color trackColor;

  MultiSegmentPiePainter({
    required this.segments,
    required this.totalMinutes,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 18.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;
    final Rect boundingSquare = Rect.fromCircle(center: center, radius: radius);

    final Paint paintHull = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Draw base track background if screentime is zero
    if (totalMinutes <= 0 || segments.isEmpty) {
      paintHull.color = trackColor;
      canvas.drawCircle(center, radius, paintHull);
      return;
    }

    // 2. Loop and paint continuous relative proportional arcs
    double currentStartAngle =
        -pi / 2; // Start from top 12 o'clock center marker

    for (var segment in segments) {
      final double segmentMins = segment.timeSpent.inMinutes.toDouble();
      if (segmentMins <= 0) continue;

      final double sweepAngle = (segmentMins / totalMinutes) * 2 * pi;

      paintHull.color = segment.color;
      canvas.drawArc(
        boundingSquare,
        currentStartAngle,
        sweepAngle,
        false,
        paintHull,
      );

      // Advance starting point vector line down the track ring
      currentStartAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant MultiSegmentPiePainter oldDelegate) {
    return oldDelegate.totalMinutes != totalMinutes ||
        oldDelegate.segments.length != segments.length;
  }
}
