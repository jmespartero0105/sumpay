import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/nearby_device.dart';

/// A single row representing a discovered or connected nearby device.
///
/// Renders the device's name, endpoint id, current [PeerConnectionState] and a
/// contextual action button (connect / disconnect / accept-reject).
class NearbyDeviceTile extends StatelessWidget {
  const NearbyDeviceTile({
    super.key,
    required this.device,
    this.onConnect,
    this.onDisconnect,
    this.onAccept,
    this.onReject,
    this.onMessage,
  });

  final NearbyDevice device;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: device.state.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  device.isConnected
                      ? Symbols.smartphone_rounded
                      : Symbols.devices_other_rounded,
                  size: 23,
                  color: device.state.color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ${device.endpointId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: device.state.label,
                color: device.state.color,
                icon: device.state.icon,
                dense: true,
              ),
            ],
          ),
          if (device.isIncoming && device.state == PeerConnectionState.pending)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    Symbols.vpn_key_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device.authenticationToken == null
                          ? 'Incoming request'
                          : 'Confirm code: ${device.authenticationToken}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Symbols.schedule_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                device.isConnected
                    ? 'Connected ${Formatters.relative(device.lastUpdated ?? device.discoveredAt)}'
                    : 'Seen ${Formatters.relative(device.lastUpdated ?? device.discoveredAt)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          ..._actions(context),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    // Incoming pending request → accept / reject.
    if (device.state == PeerConnectionState.pending &&
        device.isIncoming &&
        (onAccept != null || onReject != null)) {
      return <Widget>[
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Symbols.close_rounded, size: 20),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Symbols.check_rounded, size: 20),
                label: const Text('Accept'),
              ),
            ),
          ],
        ),
      ];
    }

    // Connected → message + disconnect.
    if (device.isConnected && onDisconnect != null) {
      return <Widget>[
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            if (onMessage != null) ...<Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Symbols.forum_rounded, size: 20),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDisconnect,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Symbols.link_off_rounded, size: 20),
                label: const Text('Disconnect'),
              ),
            ),
          ],
        ),
      ];
    }

    // Discovered and idle → connect.
    if (device.state == PeerConnectionState.found && onConnect != null) {
      return <Widget>[
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onConnect,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Symbols.link_rounded, size: 20),
          label: const Text('Connect'),
        ),
      ];
    }

    // Busy (requesting / awaiting) → spinner.
    if (device.isBusy) {
      return <Widget>[
        const SizedBox(height: 12),
        const SizedBox(
          height: 46,
          child: Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ];
    }

    return const <Widget>[];
  }
}
