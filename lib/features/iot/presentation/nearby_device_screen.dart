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
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/nearby_connection_state.dart';
import '../models/nearby_device.dart';
import '../providers/nearby_provider.dart';
import '../widgets/nearby_device_tile.dart';
import '../../messaging/providers/nearby_chat_provider.dart' show nearbyTransportProvider;

/// Screen for discovering, advertising and connecting to nearby SUMPAY devices
/// over the offline mesh extension (Bluetooth / Wi-Fi Direct).
///
/// Phase 2 covers discovery and connection management only. Sending data across
/// a connected peer (messaging) is deliberately not implemented here.
class NearbyDeviceScreen extends ConsumerStatefulWidget {
  const NearbyDeviceScreen({super.key});

  @override
  ConsumerState<NearbyDeviceScreen> createState() => _NearbyDeviceScreenState();
}

class _NearbyDeviceScreenState extends ConsumerState<NearbyDeviceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyProvider.notifier).refreshPermissions();
      // Instantiate the mesh transport so this device relays packets for the
      // mesh even when no chat is open (store-and-forward middle node).
      ref.read(nearbyTransportProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final NearbyConnectionState nearby = ref.watch(nearbyProvider);
    final NearbyController controller = ref.read(nearbyProvider.notifier);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Nearby devices',
        subtitle: 'Offline mesh extension',
        actions: <Widget>[
          if (nearby.devices.isNotEmpty)
            RoundIconButton(
              icon: Symbols.cleaning_services_rounded,
              tooltip: 'Clear inactive',
              onPressed: controller.clearInactive,
            ),
        ],
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              28,
            ),
            children: <Widget>[
              _StatusCard(state: nearby),
              if (nearby.hasError) ...<Widget>[
                const SizedBox(height: 14),
                _ErrorBanner(
                  message: nearby.errorMessage!,
                  onDismiss: controller.clearError,
                ),
              ],
              if (!nearby.permissionsGranted) ...<Widget>[
                const SizedBox(height: 14),
                _PermissionCard(
                  isRequesting: nearby.isRequestingPermissions,
                  onGrant: controller.requestPermissions,
                ),
              ],
              const SizedBox(height: AppConstants.sectionGap),
              _Controls(state: nearby, controller: controller),
              const SizedBox(height: AppConstants.sectionGap),
              SectionHeader(
                title: 'Connected devices',
                subtitle:
                    '${nearby.connectedCount} device(s) currently connected',
              ),
              if (nearby.connectedDevices.isEmpty)
                _InlineEmpty(
                  icon: Symbols.link_off_rounded,
                  message: 'No connected devices yet.',
                )
              else
                ...nearby.connectedDevices.map(
                  (NearbyDevice d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NearbyDeviceTile(
                      device: d,
                      onDisconnect: () => controller.disconnect(d.endpointId),
                      onMessage: () => context.push(
                        '${AppRoutes.nearbyChat}?endpointId=${Uri.encodeComponent(d.endpointId)}&name=${Uri.encodeComponent(d.name)}',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppConstants.sectionGap),
              SectionHeader(
                title: 'Discovered devices',
                subtitle: nearby.isDiscovering
                    ? 'Scanning for nearby devices…'
                    : '${nearby.discoveredCount} device(s) found',
              ),
              if (nearby.discoveredDevices.isEmpty)
                _InlineEmpty(
                  icon: Symbols.radar_rounded,
                  message: nearby.isDiscovering
                      ? 'Looking for nearby devices…'
                      : 'Start discovery to find nearby devices.',
                  showSpinner: nearby.isDiscovering,
                )
              else
                ...nearby.discoveredDevices.map(
                  (NearbyDevice d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NearbyDeviceTile(
                      device: d,
                      onConnect: () => controller.connect(d.endpointId),
                      onAccept: () => controller.acceptConnection(d.endpointId),
                      onReject: () => controller.rejectConnection(d.endpointId),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Keep Bluetooth, Wi-Fi and location switched on. The mesh only '
                'extends coverage when the internet is out of direct range — it is '
                'not the primary link.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final NearbyConnectionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NearbyEngineState engine = state.engineState;

    return AppCard(
      color: engine.color.withValues(alpha: 0.07),
      borderColor: engine.color.withValues(alpha: 0.25),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: engine.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(engine.icon, size: 27, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Mesh status', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(engine.label, style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  icon: Symbols.wifi_tethering_rounded,
                  label: 'Advertising',
                  value: state.isAdvertising ? 'On' : 'Off',
                  color: state.isAdvertising
                      ? AppColors.info
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              _Divider(color: theme.dividerColor),
              Expanded(
                child: _Metric(
                  icon: Symbols.radar_rounded,
                  label: 'Discovering',
                  value: state.isDiscovering ? 'On' : 'Off',
                  color: state.isDiscovering
                      ? AppColors.warning
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              _Divider(color: theme.dividerColor),
              Expanded(
                child: _Metric(
                  icon: Symbols.link_rounded,
                  label: 'Connected',
                  value: '${state.connectedCount}',
                  color: state.connectedCount > 0
                      ? AppColors.success
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Symbols.smartphone_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This device: ${state.localDeviceName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                StatusChip(
                  label: state.permissionsGranted ? 'Ready' : 'Needs access',
                  color: state.permissionsGranted
                      ? AppColors.success
                      : AppColors.warning,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});

  final NearbyConnectionState state;
  final NearbyController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Discovery controls'),
        Row(
          children: <Widget>[
            Expanded(
              child: state.isAdvertising
                  ? OutlinedButton.icon(
                      onPressed: controller.stopAdvertising,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Symbols.wifi_tethering_off_rounded),
                      label: const Text('Stop advertising'),
                    )
                  : FilledButton.icon(
                      onPressed: controller.startAdvertising,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.info,
                      ),
                      icon: const Icon(Symbols.wifi_tethering_rounded),
                      label: const Text('Advertise'),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: state.isDiscovering
                  ? OutlinedButton.icon(
                      onPressed: controller.stopDiscovery,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Symbols.stop_rounded),
                      label: const Text('Stop scan'),
                    )
                  : FilledButton.icon(
                      onPressed: controller.startDiscovery,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.warning,
                      ),
                      icon: const Icon(Symbols.radar_rounded),
                      label: const Text('Discover'),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: (state.isAdvertising && state.isDiscovering)
                    ? null
                    : controller.startAll,
                icon: const Icon(Symbols.hub_rounded),
                label: const Text('Start both'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (!state.isAdvertising &&
                        !state.isDiscovering &&
                        state.connectedCount == 0)
                    ? null
                    : controller.stopAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                ),
                icon: const Icon(Symbols.power_settings_new_rounded),
                label: const Text('Stop all'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.isRequesting, required this.onGrant});

  final bool isRequesting;
  final Future<bool> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: AppColors.warningSoft,
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Row(
        children: <Widget>[
          const Icon(
            Symbols.encrypted_rounded,
            size: 26,
            color: AppColors.warning,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Permissions required', style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  'Nearby discovery needs Bluetooth, Wi-Fi and location access.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isRequesting ? null : () => onGrant(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              minimumSize: const Size(96, 44),
            ),
            child: isRequesting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Grant'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Symbols.error_rounded, size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Symbols.close_rounded, size: 18),
            color: AppColors.danger,
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.message,
    this.showSpinner = false,
  });

  final IconData icon;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: <Widget>[
            if (showSpinner)
              const SizedBox(
                height: 30,
                width: 30,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              )
            else
              Icon(
                icon,
                size: 34,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.titleMedium),
        const SizedBox(height: 1),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 46, color: color);
  }
}
