import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/state_views.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/providers/sos_mesh_provider.dart';

/// Barangay situational map for officials: plots every incoming SOS incident
/// that carries coordinates onto an OpenStreetMap view, colour-coded by status.
/// Tiles stream live from OSM (pre-caching can be added later).
class BarangayMapScreen extends ConsumerStatefulWidget {
  const BarangayMapScreen({super.key});

  @override
  ConsumerState<BarangayMapScreen> createState() => _BarangayMapScreenState();
}

class _BarangayMapScreenState extends ConsumerState<BarangayMapScreen> {
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  // Default center: approximate Philippines centroid, used only when no
  // incident has coordinates yet.
  static const LatLng _fallbackCenter = LatLng(14.6760, 121.0437);

  final MapController _controller = MapController();
  bool _tilesUnavailable = false;

  Color _statusColor(SosStatus status) => switch (status) {
        SosStatus.resolved => AppColors.success,
        SosStatus.rejected => AppColors.textSecondary,
        SosStatus.cancelled => AppColors.textSecondary,
        SosStatus.responderAccepted ||
        SosStatus.responderEnRoute ||
        SosStatus.arrived =>
          AppColors.info,
        _ => AppColors.emergency,
      };

  @override
  Widget build(BuildContext context) {
    final List<TrackedSos> tracked = ref.watch(sosMeshProvider);
    // Only ACTIVE incidents belong on the map — resolved, cancelled and
    // rejected SOS are removed so officials see only what still needs attention.
    final List<TrackedSos> located = tracked
        .where((TrackedSos t) =>
            !t.status.isTerminal &&
            t.packet.latitude != null &&
            t.packet.longitude != null)
        .toList();

    // Responders currently engaged (accepted / en route / arrived) whose
    // location was captured at acceptance, for live monitoring on the map.
    final List<TrackedSos> responders = tracked
        .where((TrackedSos t) =>
            t.packet.actorLat != null &&
            t.packet.actorLng != null &&
            (t.status == SosStatus.responderAccepted ||
                t.status == SosStatus.responderEnRoute ||
                t.status == SosStatus.arrived))
        .toList();

    final LatLng center = located.isNotEmpty
        ? LatLng(located.first.packet.latitude!,
            located.first.packet.longitude!)
        : _fallbackCenter;

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Barangay map',
        subtitle: '${located.length} SOS • ${responders.length} responder'
            '${responders.length == 1 ? '' : 's'}',
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: located.isNotEmpty ? 15 : 6,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.sumpay.app',
                errorTileCallback:
                    (TileImage tile, Object error, StackTrace? stackTrace) {
                  if (!_tilesUnavailable && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tilesUnavailable = true);
                    });
                  }
                },
              ),
              MarkerLayer(
                markers: <Marker>[
                  for (final TrackedSos t in located)
                    Marker(
                      point: LatLng(
                          t.packet.latitude!, t.packet.longitude!),
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message:
                            '${t.packet.emergencyType.label} — ${t.packet.residentName}',
                        child: Icon(
                          Symbols.location_on_rounded,
                          color: _statusColor(t.status),
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
              MarkerLayer(
                markers: <Marker>[
                  for (final TrackedSos t in responders)
                    Marker(
                      point:
                          LatLng(t.packet.actorLat!, t.packet.actorLng!),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message:
                            'Responder: ${t.responderName ?? t.packet.actorName ?? 'Unknown'}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Symbols.directions_run_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: <SourceAttribution>[
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  _LegendRow(
                      icon: Symbols.location_on_rounded,
                      color: AppColors.emergency,
                      label: 'SOS incident'),
                  SizedBox(height: 4),
                  _LegendRow(
                      icon: Symbols.directions_run_rounded,
                      color: AppColors.info,
                      label: 'Responder'),
                ],
              ),
            ),
          ),
          if (located.isEmpty && responders.isEmpty)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Card(
                    margin: EdgeInsets.all(32),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyState(
                        icon: Symbols.location_off_rounded,
                        title: 'No located incidents',
                        message:
                            'Incoming SOS reports with location data will appear '
                            'here on the map.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_tilesUnavailable)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Symbols.cloud_off_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Map tiles need internet. Incident coordinates are still accurate.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
