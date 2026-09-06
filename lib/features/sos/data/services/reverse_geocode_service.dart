import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Turns coordinates into a human-readable address using OpenStreetMap's free
/// Nominatim reverse-geocoding endpoint, so SOS logs and the map show the exact
/// place (street / barangay / municipality) rather than only lat-long numbers.
///
/// Uses the cross-platform [http] package so it works on both mobile and web.
/// Coordinates remain the authoritative record; this only adds a readable label
/// when online. On any failure (offline, timeout, sparse rural data) it returns
/// null and the caller keeps the coordinate string.
class ReverseGeocodeService {
  const ReverseGeocodeService();

  static const String _host = 'nominatim.openstreetmap.org';
  // Nominatim's usage policy requires a descriptive User-Agent identifying the
  // app. See https://operations.osmfoundation.org/policies/nominatim/
  static const String _userAgent = 'SUMPAY-Emergency-App/1.0 (barangay-mesh)';

  /// Returns a readable address for [lat],[lng], or null if unavailable.
  Future<String?> lookup(
    double lat,
    double lng, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final Uri uri = Uri.https(_host, '/reverse', <String, String>{
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'jsonv2',
        'zoom': '18', // building / street level
        'addressdetails': '1',
      });

      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      return _formatAddress(json);
    } on TimeoutException {
      return null;
    } catch (error) {
      debugPrint('ReverseGeocode: lookup failed: $error');
      return null;
    }
  }

  /// Builds a concise, most-specific-first address from a Nominatim response.
  /// Falls back to the raw display_name, then null.
  String? _formatAddress(Map<String, dynamic> json) {
    final Object? addr = json['address'];
    if (addr is Map) {
      final Map<String, dynamic> a = Map<String, dynamic>.from(addr);
      final List<String> parts = <String>[];
      void add(String? v) {
        if (v != null && v.trim().isNotEmpty && !parts.contains(v)) {
          parts.add(v.trim());
        }
      }

      add(a['amenity'] as String?);
      add(a['building'] as String?);
      add(a['road'] as String?);
      add((a['neighbourhood'] ?? a['suburb'] ?? a['quarter']) as String?);
      add((a['village'] ??
          a['hamlet'] ??
          a['town'] ??
          a['city_district']) as String?);
      add((a['city'] ?? a['municipality']) as String?);
      add((a['state'] ?? a['province']) as String?);

      if (parts.isNotEmpty) {
        return parts.take(4).join(', ');
      }
    }

    final Object? display = json['display_name'];
    if (display is String && display.trim().isNotEmpty) {
      return display.split(',').take(4).map((String s) => s.trim()).join(', ');
    }
    return null;
  }
}
