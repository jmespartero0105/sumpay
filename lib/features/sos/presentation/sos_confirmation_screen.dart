import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/lottie_placeholder.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../widgets/active_sos_map.dart';
import '../models/responder.dart';
import '../models/sos_request.dart';
import '../providers/resident_sos_notification_provider.dart';
import '../providers/sos_provider.dart';

/// Post-submission acknowledgement showing relay progress.
class SosConfirmationScreen extends ConsumerStatefulWidget {
  const SosConfirmationScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<SosConfirmationScreen> createState() =>
      _SosConfirmationScreenState();
}

class _SosConfirmationScreenState
    extends ConsumerState<SosConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    _simulateAcknowledgement();
  }

  Future<void> _simulateAcknowledgement() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    ref.read(sosLogProvider.notifier).markDelivered(widget.requestId);
  }

  Future<void> _resolve(SosRequest request) async {
    final bool confirmed = await AppDialogs.confirm(
      context,
      title: 'Resolve this emergency?',
      message:
          'Confirm only when your emergency is fully handled. Responders and '
          'the barangay will be notified that it is resolved.',
      confirmLabel: 'Yes, resolved',
      cancelLabel: 'Not yet',
      icon: Symbols.check_circle_rounded,
      accent: AppColors.success,
    );
    if (!confirmed || !mounted) return;

    ref.read(sosLogProvider.notifier).resolve(request.id);
    if (!mounted) return;
    AppDialogs.snack(context, 'Your emergency has been marked resolved.',
        icon: Symbols.check_circle_rounded);
    context.go(AppRoutes.home);
  }

  Future<void> _cancel(SosRequest request) async {
    final bool confirmed = await AppDialogs.confirm(
      context,
      title: 'Cancel this request?',
      message:
          'Responders will be notified that assistance is no longer needed at ${request.locationLabel}.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep active',
      icon: Symbols.cancel_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    ref.read(sosLogProvider.notifier).cancel(request.id);
    if (!mounted) return;
    AppDialogs.snack(context, 'Emergency request cancelled.',
        icon: Symbols.check_circle_rounded);
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SosRequest> log = ref.watch(sosLogProvider);

    SosRequest? request;
    for (final SosRequest r in log) {
      if (r.id == widget.requestId) {
        request = r;
        break;
      }
    }

    if (request == null) {
      return Scaffold(
        body: SafeArea(
          child: ErrorState(
            message: 'This emergency request could not be found.',
            onRetry: () => context.go(AppRoutes.home),
          ),
        ),
      );
    }

    // "Delivered" only means the SOS reached the network — NOT that anyone is
    // coming. Help is only genuinely on the way once a responder has accepted
    // (status == responding). Keep these distinct so we never give a false
    // sense of security.
    final bool delivered = request.delivery == DeliveryStatus.delivered;
    // The full list of responders for this SOS, tracked independently of the
    // mesh SOS list so the resident sees everyone who accepted (stacking).
    final List<Responder> respondersForSos =
        ref.watch(respondersBySosProvider)[request.id] ?? <Responder>[];
    final bool hasResponder = respondersForSos.isNotEmpty ||
        (request.status == IncidentStatus.responding &&
            request.respondingUnit != null);
    final bool acknowledged = hasResponder;

    return Scaffold(
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              20,
              context.pageInset,
              24,
            ),
            children: <Widget>[
              Center(
                child: LottiePlaceholder(
                  asset: acknowledged
                      ? AppConstants.lottieSuccess
                      : AppConstants.lottieEmergency,
                  fallbackIcon: acknowledged
                      ? Symbols.check_circle_rounded
                      : request.type.icon,
                  color: acknowledged
                      ? AppColors.success
                      : request.type.color,
                  size: 168,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasResponder
                    ? 'Help is on the way'
                    : delivered
                        ? 'Waiting for a responder…'
                        : 'Transmitting your SOS…',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                hasResponder
                    ? 'A responder has accepted your request and is on the way.'
                    : delivered
                        ? 'Your SOS reached the barangay. Waiting for a responder to accept — your request stays active.'
                        : 'Your request is being sent to the barangay over the SUMPAY Network.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: request.type.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            request.type.icon,
                            size: 25,
                            color: request.type.color,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${request.type.label} emergency',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reference ${request.id}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusChip(
                          label: request.priority.label,
                          color: request.priority.color,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: theme.dividerColor, height: 1),
                    const SizedBox(height: 6),
                    DetailRow(
                      label: 'Submitted',
                      value: Formatters.dateTime(request.createdAt),
                      icon: Symbols.schedule_rounded,
                    ),
                    DetailRow(
                      label: 'Location',
                      value: request.locationLabel,
                      icon: Symbols.location_on_rounded,
                    ),
                    DetailRow(
                      label: 'Coordinates',
                      value: request.coordinates,
                      icon: Symbols.my_location_rounded,
                    ),
                    DetailRow(
                      label: 'People affected',
                      value: '${request.peopleAffected}',
                      icon: Symbols.groups_rounded,
                    ),
                    if (respondersForSos.isNotEmpty)
                      ...respondersForSos.map((Responder r) => DetailRow(
                            label: 'Responder',
                            value:
                                '${r.name} • ${r.state.label}${_responderDistance(request!, r)}',
                            icon: r.state == ResponderState.onScene
                                ? Symbols.pin_drop_rounded
                                : r.state == ResponderState.enRoute
                                    ? Symbols.directions_run_rounded
                                    : Symbols.handshake_rounded,
                          ))
                    else if (request.respondingUnit != null)
                      DetailRow(
                        label: 'Responding unit',
                        value: request.respondingUnit!,
                        icon: Symbols.local_shipping_rounded,
                      ),
                  ],
                ),
              ),
              if ((request.status == IncidentStatus.active ||
                      request.status == IncidentStatus.responding) &&
                  request.latitude != 0 &&
                  request.longitude != 0) ...<Widget>[
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Live tracking',
                  subtitle: respondersForSos.isEmpty
                      ? 'Your location. Responders appear here once they accept.'
                      : 'You and ${respondersForSos.length} responder'
                          '${respondersForSos.length == 1 ? '' : 's'} on the map.',
                ),
                const SizedBox(height: 8),
                ActiveSosMap(
                  residentLat: request.latitude,
                  residentLng: request.longitude,
                  responders: respondersForSos,
                ),
              ],
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Relay progress', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _RelayStep(
                      label: 'Sent from your device',
                      detail: 'Your SOS has been created',
                      done: true,
                      isLast: false,
                    ),
                    _RelayStep(
                      label: 'Sent over the SUMPAY Network',
                      detail: 'Relayed toward the barangay',
                      done: true,
                      isLast: false,
                    ),
                    _RelayStep(
                      label: 'Received by the barangay',
                      detail: delivered
                          ? 'Your SOS reached the barangay'
                          : 'Waiting to reach the barangay…',
                      done: delivered,
                      isLast: false,
                    ),
                    _RelayStep(
                      label: 'A responder accepted',
                      detail: hasResponder
                          ? 'A responder is on the way'
                          : 'Waiting for a responder…',
                      done: hasResponder,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (request.status == IncidentStatus.active ||
                  request.status == IncidentStatus.responding) ...<Widget>[
                FilledButton.icon(
                  onPressed: () => _resolve(request!),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Symbols.check_circle_rounded),
                  label: const Text('Mark my emergency as resolved'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Symbols.home_rounded),
                label: const Text('Back to dashboard'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _cancel(request!),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Symbols.cancel_rounded),
                label: const Text('Cancel this emergency request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelayStep extends StatelessWidget {
  const _RelayStep({
    required this.label,
    required this.detail,
    required this.done,
    required this.isLast,
  });

  final String label;
  final String detail;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = done ? AppColors.success : theme.dividerColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              AnimatedContainer(
                duration: AppConstants.mediumAnim,
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(
                        Symbols.check_rounded,
                        size: 15,
                        color: Colors.white,
                        weight: 700,
                      )
                    : const SizedBox.shrink(),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats " • 320 m" / " • 1.4 km" for a responder relative to the resident's
/// SOS location, or an empty string when the responder has no coordinates.
String _responderDistance(SosRequest request, Responder r) {
  if (r.latitude == null || r.longitude == null) return '';
  if (request.latitude == 0 && request.longitude == 0) return '';
  const Distance distance = Distance();
  final double metres = distance.as(
    LengthUnit.Meter,
    LatLng(request.latitude, request.longitude),
    LatLng(r.latitude!, r.longitude!),
  );
  if (metres < 1000) return ' • ${metres.round()} m away';
  return ' • ${(metres / 1000).toStringAsFixed(1)} km away';
}
