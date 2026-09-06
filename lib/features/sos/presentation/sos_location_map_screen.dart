import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bars.dart';
import '../models/sos_location_model.dart';

/// Fullscreen OpenStreetMap view of a resident's SOS location, opened from the
/// responder/official incoming-SOS card. Shows the pin and accuracy circle on a
/// larger, interactive map so the responder can see the surrounding area.
class SosLocationMapScreen extends StatefulWidget {
  const SosLocationMapScreen({
    super.key,
    required this.location,
    this.label,
  });

  final SosLocationModel location;
  final String? label;

  @override
  State<SosLocationMapScreen> createState() => _SosLocationMapScreenState();
}

class _SosLocationMapScreenState extends State<SosLocationMapScreen> {
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _userAgent = 'com.sumpay.app';
  final MapController _controller = MapController();
  bool _tilesUnavailable = false;

  @override
  Widget build(BuildContext context) {
    final SosLocationModel loc = widget.location;
    final LatLng point = LatLng(loc.latitude, loc.longitude);

    return Scaffold(
      appBar: SumpayAppBar(
        title: widget.label ?? 'SOS location',
        subtitle: loc.coordinateLabel,
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 17,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: _userAgent,
                errorTileCallback:
                    (TileImage tile, Object error, StackTrace? stackTrace) {
                  if (!_tilesUnavailable && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tilesUnavailable = true);
                    });
                  }
                },
              ),
              CircleLayer<Object>(
                circles: <CircleMarker<Object>>[
                  CircleMarker<Object>(
                    point: point,
                    radius: loc.accuracy,
                    useRadiusInMeter: true,
                    color: AppColors.emergency.withValues(alpha: 0.15),
                    borderColor: AppColors.emergency.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: point,
                    width: 48,
                    height: 48,
                    child: const Icon(Symbols.person_pin_circle_rounded,
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
                        'Map tiles unavailable offline — coordinates are still accurate.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: _tilesUnavailable ? 76 : 16,
            child: FloatingActionButton.small(
              onPressed: () => _controller.move(point, 17),
              backgroundColor: AppColors.emergency,
              child: const Icon(Symbols.my_location_rounded,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
