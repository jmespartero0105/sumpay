import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../models/responder.dart';

/// A compact, embedded map for the resident's active-SOS screen. Shows the
/// resident's own location (red pin) and every accepted responder (blue markers
/// labelled with their name), so tracking lives on the same page as the SOS
/// details — no extra taps.
class ActiveSosMap extends StatefulWidget {
  const ActiveSosMap({
    super.key,
    required this.residentLat,
    required this.residentLng,
    required this.responders,
    this.height = 260,
  });

  final double residentLat;
  final double residentLng;
  final List<Responder> responders;
  final double height;

  @override
  State<ActiveSosMap> createState() => _ActiveSosMapState();
}

class _ActiveSosMapState extends State<ActiveSosMap> {
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final MapController _controller = MapController();
  bool _tilesUnavailable = false;

  List<Responder> get _locatedResponders => widget.responders
      .where((Responder r) => r.latitude != null && r.longitude != null)
      .toList();

  /// Straight-line distance from the resident to a responder, formatted as a
  /// short label (e.g. "320 m" or "1.4 km").
  String _distanceLabel(Responder r) {
    if (r.latitude == null || r.longitude == null) return '';
    const Distance distance = Distance();
    final double metres = distance.as(
      LengthUnit.Meter,
      LatLng(widget.residentLat, widget.residentLng),
      LatLng(r.latitude!, r.longitude!),
    );
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = LatLng(widget.residentLat, widget.residentLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: <Widget>[
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
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
                        if (mounted) {
                          setState(() => _tilesUnavailable = true);
                        }
                      });
                    }
                  },
                ),
                // Responder markers (blue, labelled with name).
                MarkerLayer(
                  markers: <Marker>[

                  ],
                ),
                // Resident's own location (red pin).
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: const Icon(Symbols.emergency_home_rounded,
                          color: AppColors.emergency, size: 40),
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
            // Legend.
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _LegendDot(
                        color: AppColors.emergency, label: 'You'),
                    SizedBox(height: 3),
                    _LegendDot(color: AppColors.info, label: 'Responder'),
                  ],
                ),
              ),
            ),
            if (_tilesUnavailable)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Map needs internet. Location is still tracked.',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
