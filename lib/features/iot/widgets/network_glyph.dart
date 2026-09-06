import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../data/services/connectivity_service.dart';

/// The single, most-meaningful network state to show in the compact home icon.
/// Deliberately one value (not a combination) so the icon never overloads the
/// resident with technical detail. Ordered by importance for display.
enum NetworkGlyphState {
  internet,
  mesh,
  wifi,
  bluetooth,
  connecting,
  offline,
}

/// Visual representation (icon, colour, label) for a network state.
class NetworkGlyph {
  const NetworkGlyph({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;

  /// Short, human label used for the tooltip and semantic label.
  final String label;
}

/// Reduces the full [ConnectivitySnapshot] to the single most meaningful state
/// for the compact home icon, using a priority order:
/// internet > mesh > wifi medium > bluetooth > connecting > offline.
NetworkGlyphState resolveNetworkGlyphState(ConnectivitySnapshot s) {
  if (s.internet == LinkState.connected) return NetworkGlyphState.internet;
  if (s.mesh == LinkState.connected) return NetworkGlyphState.mesh;
  if (s.internet == LinkState.connecting) return NetworkGlyphState.connecting;
  if (s.wifi == LinkState.connected) return NetworkGlyphState.wifi;
  if (s.bluetooth == LinkState.connected) return NetworkGlyphState.bluetooth;
  return NetworkGlyphState.offline;
}

/// Maps a state to its icon, colour and label.
NetworkGlyph networkGlyphFor(NetworkGlyphState state) {
  switch (state) {
    case NetworkGlyphState.internet:
      return const NetworkGlyph(
        icon: Symbols.cloud_done_rounded,
        color: AppColors.success,
        label: 'Connected (Internet)',
      );
    case NetworkGlyphState.mesh:
      return const NetworkGlyph(
        icon: Symbols.hub_rounded,
        color: AppColors.success,
        label: 'Mesh active',
      );
    case NetworkGlyphState.wifi:
      return const NetworkGlyph(
        icon: Symbols.wifi_rounded,
        color: AppColors.info,
        label: 'Wi-Fi active',
      );
    case NetworkGlyphState.bluetooth:
      return const NetworkGlyph(
        icon: Symbols.bluetooth_rounded,
        color: AppColors.info,
        label: 'Bluetooth active',
      );
    case NetworkGlyphState.connecting:
      return const NetworkGlyph(
        icon: Symbols.sync_rounded,
        color: AppColors.warning,
        label: 'Connecting',
      );
    case NetworkGlyphState.offline:
      return const NetworkGlyph(
        icon: Symbols.cloud_off_rounded,
        color: AppColors.danger,
        label: 'Offline',
      );
  }
}
