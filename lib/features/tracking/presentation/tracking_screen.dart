import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bars.dart';
import '../models/tracking_state.dart';
import '../providers/tracking_provider.dart';

/// Emergency responder tracking screen backed by OpenStreetMap (flutter_map).
///
/// Map tiles require network access to load, but this screen is entirely
/// separate from SOS/mesh communication: if tiles fail, messaging is
/// unaffected. The map data (marker points) comes from the mesh-delivered
/// responder response, not from any map service.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _map = MapController();
  static const MapService _service = OsmMapService();

  /// Set when OSM tiles fail to load (e.g. offline). Display-only: this never
  /// affects SOS/mesh, which share no code with the map.
  bool _tilesUnavailable = false;

  void _center(LatLng? point) {
    if (point == null) return;
    _map.move(point, _service.defaultZoom);
  }

  void _fitBoth(TrackingState state) {
    // Prefer showing responder; fall back to resident/SOS.
    _center(state.responder ?? state.resident ?? state.sosLocation);
  }

  @override
  Widget build(BuildContext context) {
    final TrackingState? state = ref.watch(trackingStateProvider);

    if (state == null) {
      return Scaffold(
        appBar: const SumpayAppBar(title: 'Track Responder'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No active responder to track right now.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final LatLng center = state.responder ??
        state.resident ??
        state.sosLocation ??
        _service.defaultCenter;

    return Scaffold(
      appBar: const SumpayAppBar(title: 'Track Responder'),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _service.defaultZoom,
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: _service.tileUrlTemplate,
                userAgentPackageName: _service.userAgentPackageName,
                errorTileCallback:
                    (TileImage tile, Object error, StackTrace? stackTrace) {
                  // Tiles failed to load (typically offline). Flag it for the
                  // banner. This is display-only and never touches SOS/mesh.
                  if (!_tilesUnavailable && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tilesUnavailable = true);
                    });
                  }
                },
              ),
              // Route/path placeholder: a straight line between responder and
              // resident until real routing is added.
              if (state.responder != null && state.resident != null)
                PolylineLayer<Object>(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: <LatLng>[state.responder!, state.resident!],
                      strokeWidth: 4,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: state.markers
                    .map((TrackingMarker m) => Marker(
                          point: m.point,
                          width: 44,
                          height: 44,
                          child: _MarkerPin(kind: m.kind),
                        ))
                    .toList(),
              ),
              const RichAttributionWidget(
                attributions: <SourceAttribution>[
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_tilesUnavailable)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Symbols.cloud_off_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Map tiles unavailable offline. Responder status and '
                          'locations are still shown below.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: _tilesUnavailable ? 64 : 12,
            child: Column(
              children: <Widget>[
                _MapButton(
                  icon: Symbols.person_pin_circle_rounded,
                  tooltip: 'Center on you',
                  onTap: () => _center(state.resident),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Symbols.volunteer_activism_rounded,
                  tooltip: 'Center on responder',
                  onTap: () => _center(state.responder),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Symbols.fit_screen_rounded,
                  tooltip: 'Recenter',
                  onTap: () => _fitBoth(state),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Symbols.add_rounded,
                  tooltip: 'Zoom in',
                  onTap: () => _map.move(
                      _map.camera.center, _map.camera.zoom + 1),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Symbols.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: () => _map.move(
                      _map.camera.center, _map.camera.zoom - 1),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _StatusPanel(state: state),
          ),
        ],
      ),
    );
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.kind});

  final TrackingMarkerKind kind;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (kind) {
      TrackingMarkerKind.resident => (
          Symbols.person_pin_circle_rounded,
          AppColors.info
        ),
      TrackingMarkerKind.responder => (
          Symbols.volunteer_activism_rounded,
          AppColors.success
        ),
      TrackingMarkerKind.sos => (Symbols.sos_rounded, AppColors.emergency),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Symbols.volunteer_activism_rounded,
                  color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(state.responderName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (state.responderRole != null)
                Text(state.responderRole!.label,
                    style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(Symbols.navigation_rounded,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(state.statusLabel,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.success)),
            ],
          ),
          if (state.lastUpdated != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Last update: ${Formatters.relative(state.lastUpdated!)}',
                style: theme.textTheme.labelSmall),
          ],
          if (state.distanceLabel != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(Symbols.straighten_rounded,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text('${state.distanceLabel} away (straight line)',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ],
          if (state.responder == null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Responder location not yet available',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ],
      ),
    );
  }
}
