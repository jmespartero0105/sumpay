import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Four-bar signal indicator driven by a 0..4 strength value.
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.strength,
    this.height = 20,
    this.barWidth = 5,
    this.color,
  });

  /// Signal strength expressed on a 0 (none) to 4 (excellent) scale.
  final int strength;
  final double height;
  final double barWidth;
  final Color? color;

  /// Maps an RSSI reading in dBm onto the 0..4 scale.
  static int strengthFromRssi(int rssi) {
    if (rssi >= -70) return 4;
    if (rssi >= -85) return 3;
    if (rssi >= -100) return 2;
    if (rssi >= -115) return 1;
    return 0;
  }

  /// Colour associated with a strength value.
  static Color colorFor(int strength) {
    if (strength >= 3) return AppColors.success;
    if (strength == 2) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final Color active = color ?? colorFor(strength);
    final Color inactive = Theme.of(context).dividerColor;

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(4, (int index) {
          final bool on = index < strength;
          return Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 3),
            child: AnimatedContainer(
              duration: AppConstants.shortAnim,
              curve: Curves.easeOut,
              width: barWidth,
              height: height * (0.35 + (index * 0.215)),
              decoration: BoxDecoration(
                color: on ? active : inactive,
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Horizontal battery gauge used on IoT node cards.
class BatteryGauge extends StatelessWidget {
  const BatteryGauge({
    super.key,
    required this.percentage,
    this.width = 46,
    this.height = 20,
  });

  final double percentage;
  final double width;
  final double height;

  Color get _color {
    if (percentage >= 50) return AppColors.success;
    if (percentage >= 20) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final double clamped = percentage.clamp(0, 100) / 100;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1.6),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clamped == 0 ? 0.02 : clamped,
              child: AnimatedContainer(
                duration: AppConstants.mediumAnim,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 2.5,
          height: height * 0.4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
