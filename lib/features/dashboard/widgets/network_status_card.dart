import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/signal_bars.dart';
import '../../../core/widgets/status_chip.dart';
import '../../iot/models/network_models.dart';

/// Summary of gateway, LoRa and mesh state shown on the home dashboard.
class NetworkStatusCard extends StatelessWidget {
  const NetworkStatusCard({
    super.key,
    required this.status,
    this.onTap,
  });

  final NetworkStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int strength = SignalBars.strengthFromRssi(status.rssi);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: status.linkMode.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  status.linkMode.icon,
                  size: 24,
                  color: status.linkMode.color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Network status', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      status.linkMode.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: status.qualityLabel,
                color: status.linkMode.color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Connected gateway', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      status.isOffline ? 'No gateway in range' : status.gatewayId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      status.isOffline
                          ? 'Searching for nearby nodes'
                          : status.gatewayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  SignalBars(strength: strength, height: 22),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.rssi(status.rssi),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  icon: Symbols.settings_input_antenna_rounded,
                  label: 'LoRa',
                  value: status.loRaActive ? 'Active' : 'Down',
                  color: status.loRaActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
              _Separator(color: theme.dividerColor),
              Expanded(
                child: _MiniStat(
                  icon: Symbols.hub_rounded,
                  label: 'Mesh',
                  value: status.meshActive
                      ? '${status.meshPeers} peers'
                      : 'Inactive',
                  color: status.meshActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              _Separator(color: theme.dividerColor),
              Expanded(
                child: _MiniStat(
                  icon: Symbols.route_rounded,
                  label: 'Hops',
                  value: status.isOffline ? '—' : '${status.hopCount}',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (status.queuedPackets > 0) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LinkMode.offline.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Symbols.schedule_send_rounded,
                    size: 18,
                    color: LinkMode.offline.color,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${status.queuedPackets} item(s) queued • last sync ${Formatters.relative(status.lastSync)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LinkMode.offline.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(icon, size: 21, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 1),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: color);
  }
}
