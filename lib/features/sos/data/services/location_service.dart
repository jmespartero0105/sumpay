import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/sos_location_model.dart';
import 'location_permission_handler.dart';

/// Why a location capture did not produce a fix.
enum LocationFailure {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  error,
}

/// The result of attempting to capture the device's location for an SOS.
class LocationResult {
  const LocationResult._({this.location, this.failure});

  factory LocationResult.success(SosLocationModel location) =>
      LocationResult._(location: location);

  factory LocationResult.failed(LocationFailure failure) =>
      LocationResult._(failure: failure);

  final SosLocationModel? location;
  final LocationFailure? failure;

  bool get isSuccess => location != null;
}

/// Captures a single GPS fix for an SOS.
///
/// The service intentionally exposes only a one-shot [capture]. It does not, and
/// must not, stream or continuously update location — the resident's position is
/// read once, at the moment the SOS is created. The concrete plugin
/// ([Geolocator]) is confined to this class so the rest of the app depends only
/// on [SosLocationModel].
class LocationService {
  const LocationService({
    LocationPermissionHandler permissions = const LocationPermissionHandler(),
  }) : _permissions = permissions;

  final LocationPermissionHandler _permissions;

  LocationPermissionHandler get permissions => _permissions;

  /// Requests permission if needed, then captures one position.
  Future<LocationResult> capture({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final LocationAccess access = await _permissions.ensure();
    switch (access) {
      case LocationAccess.denied:
        return LocationResult.failed(LocationFailure.denied);
      case LocationAccess.deniedForever:
        return LocationResult.failed(LocationFailure.deniedForever);
      case LocationAccess.serviceDisabled:
        return LocationResult.failed(LocationFailure.serviceDisabled);
      case LocationAccess.granted:
        break;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      final DateTime capturedAt =
          (position.timestamp as DateTime?) ?? DateTime.now();
      return LocationResult.success(
        SosLocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          capturedAt: capturedAt,
        ),
      );
    } on Exception catch (error) {
      debugPrint('LocationService: capture failed: $error');
      // A timeout surfaces as a TimeoutException from the plugin.
      if (error.toString().toLowerCase().contains('time')) {
        return LocationResult.failed(LocationFailure.timeout);
      }
      return LocationResult.failed(LocationFailure.error);
    }
  }
}
