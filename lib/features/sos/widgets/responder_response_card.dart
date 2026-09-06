import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/sos_packet.dart';
import '../providers/responder_response_provider.dart';

/// A prominent GREEN card shown on the resident's home when a responder has
/// accepted / is responding to their SOS. Green is used specifically to signal
/// that the emergency has been acknowledged by a responder. This is an
/// SOS-associated response event, not a chat message.
class ResponderResponseCard extends StatelessWidget {
  const ResponderResponseCard({super.key, required this.response});

  final ResponderResponse response;

  String _statusLine(SosStatus s) => switch (s) {
        SosStatus.responderAccepted => 'Responder accepted your SOS',
        SosStatus.responderEnRoute => 'Responder is on the way',
        SosStatus.arrived => 'Responder has arrived',
        SosStatus.resolved => 'Incident resolved',
        _ => 'Responder is responding',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color green = AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.check_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusLine(response.status),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(response.responderName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (response.responderRole != null)
            Text(response.responderRole!.label,
                style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Symbols.schedule_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(Formatters.relative(response.receivedAt),
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
