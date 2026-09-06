import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../models/sos_location_model.dart';

/// A compact OpenStreetMap preview centred on a [SosLocationModel], used by the
/// SOS composer and the responder/official dashboards to show a resident's
/// captured position. When accuracy is available it draws a translucent circle
/// sized to the GPS accuracy radius, so the fix quality is visible at a glance.
///
/// The class name is kept for backwards compatibility with existing callers
/// (it used to render a non-map placeholder). It renders a real map now, but
/// degrades gracefully: with no location it shows a capture prompt, and if map
/// tiles fail to load (e.g. offline) the coordinates still show via the caller.
class MapPreviewPlaceholder extends StatefulWidget {
  const MapPreviewPlaceholder({
    super.key,
    this.location,
    this.height = 160,
    this.label,
  });

  /// The location to centre on. Null renders an empty capture-prompt state.
  final SosLocationModel? location;

  /// Preview height.
  final double height;

  /// Optional caption shown on the marker (e.g. a resident name).
  final String? label;

  @override
  State<MapPreviewPlaceholder> createState() => _MapPreviewPlaceholderState();
}

class _MapPreviewPlaceholderState extends State<MapPreviewPlaceholder> {
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _userAgent = 'com.sumpay.app';

  bool _tilesUnavailable = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SosLocationModel? loc = widget.location;

    if (loc == null) {
      // No fix yet: show a simple prompt, not a broken map.
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: AppColors.info.withValues(alpha: 0.08),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Symbols.location_searching_rounded,
                    color: AppColors.info, size: 30),
                const SizedBox(height: 6),
                Text('No location captured yet',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    final LatLng point = LatLng(loc.latitude, loc.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  // Allow pinch-zoom and drag, but no rotation for simplicity.
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
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
                        if (mounted) {
                          setState(() => _tilesUnavailable = true);
                        }
                      });
                    }
                  },
                ),
                // Accuracy circle: radius is the GPS accuracy in metres, so a
                // larger circle means a less precise fix.
                CircleLayer<Object>(
                  circles: <CircleMarker<Object>>[
                    CircleMarker<Object>(
                      point: point,
                      radius: loc.accuracy,
                      useRadiusInMeter: true,
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderColor: AppColors.info.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      child: const _ResidentPin(),
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
            // Accuracy chip (top-left).
            Positioned(
              top: 8,
              left: 8,
              child: _Chip(
                icon: Symbols.my_location_rounded,
                text: 'Accuracy ${loc.accuracyLabel}',
              ),
            ),
            // Optional label chip (top-right), e.g. resident name.
            if (widget.label != null)
              Positioned(
                top: 8,
                right: 8,
                child: _Chip(icon: Symbols.person_rounded, text: widget.label!),
              ),
            // Offline banner if tiles fail.
            if (_tilesUnavailable)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _Chip(
                  icon: Symbols.cloud_off_rounded,
                  text: 'Map offline — coordinates still captured',
                  background: AppColors.warning,
                  foreground: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResidentPin extends StatelessWidget {
  const _ResidentPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.info, width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Symbols.person_pin_circle_rounded,
          color: AppColors.info, size: 26),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String text;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bg = background ??
        theme.colorScheme.surface.withValues(alpha: 0.88);
    final Color fg =
        foreground ?? theme.colorScheme.onSurface.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

/// Actions for opening an external map or starting navigation to a [location].
/// Kept for existing callers; still inert unless handlers are supplied.
class MapActionButtons extends StatelessWidget {
  const MapActionButtons({
    super.key,
    required this.location,
    this.onOpenMap,
    this.onNavigate,
  });

  final SosLocationModel? location;
  final VoidCallback? onOpenMap;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final bool enabled = location != null;
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? (onOpenMap ?? () {}) : null,
            icon: const Icon(Symbols.map_rounded, size: 18),
            label: const Text('Open map'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? (onNavigate ?? () {}) : null,
            icon: const Icon(Symbols.navigation_rounded, size: 18),
            label: const Text('Navigate'),
          ),
        ),
      ],
    );
  }
}
