import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../models/network_models.dart';

/// Vertical schematic of the SUMPAY communication chain.
class TopologyDiagram extends StatelessWidget {
  const TopologyDiagram({super.key, required this.status});

  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    final bool meshLeg = status.linkMode == LinkMode.mesh;

    return Column(
      children: <Widget>[
        _Hop(
          icon: Symbols.smartphone_rounded,
          title: 'Your device',
          detail: 'Resident mobile app',
          active: true,
          color: AppColors.primary,
        ),
        _Connector(
          label: meshLeg
              ? 'Bluetooth / Wi-Fi Direct extension'
              : 'Direct pairing',
          active: status.meshActive,
          dashed: true,
        ),
        _Hop(
          icon: Symbols.hub_rounded,
          title: 'Neighbour mesh',
          detail: status.meshActive
              ? '${status.meshPeers} peer device(s) relaying'
              : 'Not required — gateway in direct range',
          active: status.meshActive,
          color: AppColors.warning,
        ),
        _Connector(
          label: 'Local radio link',
          active: !status.isOffline,
          dashed: false,
        ),
        _Hop(
          icon: Symbols.router_rounded,
          title: 'ESP32 gateway node',
          detail: status.isOffline ? 'Unreachable' : status.gatewayId,
          active: !status.isOffline,
          color: AppColors.info,
        ),
        _Connector(
          label: 'LoRa backbone (primary)',
          active: status.loRaActive,
          dashed: false,
        ),
        _Hop(
          icon: Symbols.cell_tower_rounded,
          title: 'Barangay command node',
          detail: 'Talay Hall • ESP32-CMD-0001',
          active: status.loRaActive,
          color: AppColors.success,
        ),
        _Connector(
          label: 'Dispatch',
          active: status.loRaActive,
          dashed: false,
        ),
        _Hop(
          icon: Symbols.groups_rounded,
          title: 'Officials and volunteers',
          detail: 'Responders receive your request',
          active: status.loRaActive,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _Hop extends StatelessWidget {
  const _Hop({
    required this.icon,
    required this.title,
    required this.detail,
    required this.active,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effective = active
        ? color
        : theme.colorScheme.onSurface.withValues(alpha: 0.35);

    return Row(
      children: <Widget>[
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: effective.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: effective.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 22, color: effective),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: effective),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({
    required this.label,
    required this.active,
    required this.dashed,
  });

  final String label;
  final bool active;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.25);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Center(
              child: SizedBox(
                height: 26,
                child: CustomPaint(
                  size: const Size(2, 26),
                  painter: _LinePainter(color: color, dashed: dashed),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
      return;
    }

    const double dash = 4;
    const double gap = 4;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
