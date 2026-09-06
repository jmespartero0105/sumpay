import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../iot/models/network_models.dart';
import '../../iot/providers/network_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/services/location_service.dart';
import '../data/services/reverse_geocode_service.dart';
import '../models/sos_location_model.dart';
import '../models/sos_request.dart';
import '../providers/location_provider.dart';
import '../providers/sos_provider.dart';
import '../widgets/emergency_type_grid.dart';
import '../widgets/map_preview_placeholder.dart';

/// Composer for a new emergency request.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final TextEditingController _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final SosDraft draft = ref.read(sosDraftProvider);
    final AppSettings settings = ref.read(settingsProvider);
    final AppUser user = ref.read(currentUserProvider);

    // Require the resident to pick at least one emergency type before sending.
    final EmergencyType? mainType = draft.type;
    if (mainType == null) {
      AppDialogs.snack(context, 'Please choose at least one emergency type.',
          icon: Symbols.warning_rounded);
      return;
    }

    if (settings.sosConfirmationRequired) {
      final bool confirmed = await AppDialogs.confirm(
        context,
        title: draft.additionalTypes.isEmpty
            ? 'Send ${mainType.label.toLowerCase()} emergency?'
            : 'Send this emergency?',
        message: draft.additionalTypes.isEmpty
            ? 'Your location, priority and profile will be transmitted to the barangay over the SUMPAY Network. Only send this if help is genuinely needed.'
            : 'Categories: ${<String>[mainType.label, ...draft.additionalTypes.map((EmergencyType t) => t.label)].join(', ')}. Your location, priority and profile will be transmitted to the barangay. Only send this if help is genuinely needed.',
        confirmLabel: 'Send SOS',
        cancelLabel: 'Review',
        icon: Symbols.sos_rounded,
        destructive: true,
      );
      if (!confirmed) return;
    }

    // Capture the resident's location at the moment of sending. Permission is
    // only ever requested here, during an SOS.
    SosLocationModel? location = ref.read(locationProvider).location;
    if (location == null) {
      location = await _captureLocation();
      // If capture failed, let the resident choose to send without location.
      if (location == null && mounted) {
        final bool sendAnyway = await AppDialogs.confirm(
          context,
          title: 'Send without location?',
          message:
              'Your device location could not be attached. You can still send the SOS, but responders will not see your coordinates.',
          confirmLabel: 'Send anyway',
          cancelLabel: 'Cancel',
          icon: Symbols.location_off_rounded,
        );
        if (!sendAnyway) return;
      }
    }

    if (!mounted) return;

    // Reverse-geocode the captured coordinates into a readable address so logs
    // and the map show the exact place. Coordinates remain authoritative; this
    // only adds a label, and falls back silently when offline.
    String? resolvedAddressLabel;
    if (location != null) {
      resolvedAddressLabel = await const ReverseGeocodeService()
          .lookup(location.latitude, location.longitude);
    }

    if (!mounted) return;
    final SosRequest request = ref
        .read(sosLogProvider.notifier)
        .submit(draft,
            requesterName: user.fullName,
            requesterId: user.id,
            location: location,
            locationLabel: resolvedAddressLabel);

    ref.read(sosDraftProvider.notifier).reset();
    ref.read(locationProvider.notifier).reset();
    _description.clear();

    if (!mounted) return;
    context.push('${AppRoutes.sosConfirmation}?id=${request.id}');
  }

  /// Captures location and shows appropriate dialogs on failure. Returns the
  /// captured location, or null if it could not be obtained.
  Future<SosLocationModel?> _captureLocation() async {
    final SosLocationModel? location =
        await ref.read(locationProvider.notifier).capture();
    if (location != null) return location;
    if (!mounted) return null;

    final LocationFailure? failure = ref.read(locationProvider).failure;
    switch (failure) {
      case LocationFailure.deniedForever:
        await AppDialogs.confirm(
          context,
          title: 'Location permission blocked',
          message:
              'Location access is turned off for SUMPAY. Open settings to allow it so responders can find you.',
          confirmLabel: 'Open settings',
          cancelLabel: 'Not now',
          icon: Symbols.location_off_rounded,
        ).then((bool ok) {
          if (ok) ref.read(locationProvider.notifier).permissions.openSettings();
        });
      case LocationFailure.serviceDisabled:
        await AppDialogs.confirm(
          context,
          title: 'Location services are off',
          message:
              'Turn on your device location so your coordinates can be attached to the SOS.',
          confirmLabel: 'Open location settings',
          cancelLabel: 'Not now',
          icon: Symbols.my_location_rounded,
        ).then((bool ok) {
          if (ok) {
            ref.read(locationProvider.notifier).permissions.openLocationSettings();
          }
        });
      case LocationFailure.denied:
        await AppDialogs.info(
          context,
          title: 'Location permission needed',
          message:
              'SUMPAY needs location access only when you send an SOS, so responders can find you.',
          icon: Symbols.location_on_rounded,
          closeLabel: 'OK',
        );
      case LocationFailure.timeout:
      case LocationFailure.error:
      case null:
        await AppDialogs.info(
          context,
          title: 'Could not get location',
          message:
              'Your location could not be captured right now. You can retry or send without it.',
          icon: Symbols.error_rounded,
          closeLabel: 'OK',
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SosDraft draft = ref.watch(sosDraftProvider);
    final NetworkStatus network = ref.watch(networkStatusProvider);
    final SosDraftController controller = ref.read(sosDraftProvider.notifier);

    return Scaffold(
      appBar: const SumpayAppBar(
        title: 'Emergency request',
        subtitle: 'Select the help you need',
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              20,
            ),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: network.linkMode.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      network.linkMode.icon,
                      size: 20,
                      color: network.linkMode.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        network.isOffline
                            ? 'Offline — your SOS will be queued and relayed as soon as a node is in range.'
                            : 'Sending over the SUMPAY Network.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: network.linkMode.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(
                title: 'What kind of help do you need?',
                subtitle:
                    'Tap all that apply. Long-press a selected one to make it the main emergency.',
              ),
              EmergencyTypeGrid(
                selected: draft.type,
                additional: draft.additionalTypes,
                onSelected: controller.toggleType,
                onSetMain: controller.setMainType,
                columns: context.gridColumns(phone: 3, tablet: 4, desktop: 6),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Priority level'),
              AppCard(
                color: draft.priority.softColor,
                borderColor: draft.priority.color.withValues(alpha: 0.35),
                child: Row(
                  children: <Widget>[
                    Icon(Symbols.priority_high_rounded,
                        color: draft.priority.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${draft.priority.label} priority',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: draft.priority.color),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            draft.type == null
                                ? 'Set automatically once you choose an emergency type.'
                                : 'Set automatically for ${draft.type!.label.toLowerCase()} emergencies.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Your location'),
              const _SosLocationCard(),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Number of people affected'),
              AppCard(
                child: Row(
                  children: <Widget>[
                    const Icon(Symbols.groups_rounded, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'How many persons are affected?',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () =>
                          controller.setPeopleAffected(draft.peopleAffected - 1),
                      icon: const Icon(Symbols.remove_rounded),
                      iconSize: 22,
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${draft.peopleAffected}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () =>
                          controller.setPeopleAffected(draft.peopleAffected + 1),
                      icon: const Icon(Symbols.add_rounded),
                      iconSize: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: SwitchListTile(
                  value: draft.shareMedicalProfile,
                  onChanged: controller.toggleMedicalSharing,
                  title: Text(
                    'Share my medical profile',
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    'Blood type, allergies and conditions travel with this request.',
                    style: theme.textTheme.bodySmall,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  minimumSize: const Size.fromHeight(62),
                ),
                icon: const Icon(Symbols.send_rounded, size: 24),
                label: Text(
                  'Send ${draft.priority.label.toLowerCase()} priority SOS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'False alarms delay help for others. Cancel any mistaken request immediately.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Location section on the SOS composer: shows the captured coordinates, an
/// accuracy indicator, a refresh button, a map preview placeholder, and a
/// "Location Attached" status. Location is only captured on demand here.
class _SosLocationCard extends ConsumerWidget {
  const _SosLocationCard();

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(locationProvider.notifier).capture();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final LocationCaptureState state = ref.watch(locationProvider);
    final SosLocationModel? loc = state.location;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MapPreviewPlaceholder(location: loc),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                loc != null
                    ? Symbols.location_on_rounded
                    : Symbols.location_searching_rounded,
                color: loc != null ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      loc != null ? loc.coordinateLabel : 'No location captured',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc != null
                          ? 'Accuracy ${loc.accuracyLabel}'
                          : 'Tap refresh to capture your position',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: state.isCapturing ? null : () => _refresh(ref),
                icon: state.isCapturing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.refresh_rounded),
                tooltip: 'Refresh location',
              ),
            ],
          ),
          if (loc != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Symbols.check_circle_rounded,
                      color: AppColors.success, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Location attached',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
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
