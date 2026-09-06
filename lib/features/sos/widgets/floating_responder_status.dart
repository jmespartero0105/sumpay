import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sos_packet.dart';
import '../providers/responder_response_provider.dart';

/// A FoodPanda-style floating status overlay shown on the resident's home while
/// an SOS is being responded to. It hovers above the page content (rather than
/// scrolling inline), uses green styling to signal that help is coming, and
/// exposes a "Track Responder" action that opens the OpenStreetMap tracking
/// screen. It is intentionally not casually dismissible: an active emergency
/// status should not be swiped away by accident. It only disappears when the
/// incident is resolved.
class FloatingResponderStatus extends StatelessWidget {
  const FloatingResponderStatus({
    super.key,
    required this.response,
    this.sosType,
  });

  final ResponderResponse response;

  /// The emergency type of the resident's SOS, shown for context. Optional
  /// because the overlay must still render if the type can't be resolved.
  final EmergencyType? sosType;

  String get _statusLine => switch (response.status) {
        SosStatus.responderAccepted => 'Responder is on the way',
        SosStatus.responderEnRoute => 'Responder is on the way',
        SosStatus.arrived => 'Responder has arrived',
        SosStatus.resolved => 'Incident resolved',
        _ => 'Responder is responding',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color green = AppColors.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
            '${AppRoutes.sosConfirmation}?id=${response.sosId}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: green.withValues(alpha: 0.5), width: 1.3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: green.withValues(alpha: 0.15),
                child: const Icon(Symbols.volunteer_activism_rounded,
                    color: green, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(response.responderName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(_statusLine,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: green, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Symbols.map_rounded, size: 16, color: green),
                  SizedBox(width: 4),
                  Icon(Symbols.chevron_right_rounded,
                      size: 18, color: green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
