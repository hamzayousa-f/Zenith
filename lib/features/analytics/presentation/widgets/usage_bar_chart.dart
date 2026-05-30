import 'package:flutter/material.dart';

class UsageBarChart extends StatelessWidget {
  final String label;
  final Duration timeSpent;
  final Duration maxTime;
  final ImageProvider? appIcon;

  const UsageBarChart({
    super.key,
    required this.label,
    required this.timeSpent,
    required this.maxTime,
    this.appIcon,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = maxTime.inMinutes > 0
        ? (timeSpent.inMinutes / maxTime.inMinutes).clamp(0.0, 1.0)
        : 0.0;

    final int hours = timeSpent.inHours;
    final int minutes = timeSpent.inMinutes.remainder(60);
    final String timeString = hours > 0
        ? '${hours}h ${minutes}m'
        : '${minutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.01)),
      ),
      child: Row(
        children: [
          // App Icon Container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: appIcon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(image: appIcon!),
                  )
                : const Icon(Icons.android, size: 22, color: Colors.grey),
          ),
          const SizedBox(width: 14),

          // Label and Graph Core Pipelines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9E9E9F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Painted Bar Track
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
