import 'package:geolocator/geolocator.dart';

/// Outcome of a location permission / availability check, expressed in
/// app terms so the UI can respond without importing the plugin.
enum LocationAccess {
  /// Permission granted and location services are on — safe to read position.
  granted,

  /// Permission denied this time (can ask again).
  denied,

  /// Permission permanently denied — must be enabled from system settings.
  deniedForever,

  /// Permission is fine but the device's location services are switched off.
  serviceDisabled,
}

/// Thin, testable wrapper around the location plugin's permission flow.
///
/// The app only ever calls this when a resident sends an SOS, so permission is
/// requested on demand rather than at launch. It never requests background or
/// "always" access.
class LocationPermissionHandler {
  const LocationPermissionHandler();

  /// Checks current access without prompting.
  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _map(await Geolocator.checkPermission());
  }

  /// Ensures access, prompting the user once if needed. Call this at the moment
  /// an SOS is being sent.
  Future<LocationAccess> ensure() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _map(permission);
  }

  /// Opens the OS app settings so the user can grant a permanently denied
  /// permission.
  Future<void> openSettings() => Geolocator.openAppSettings();

  /// Opens the OS location settings so the user can switch services on.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  LocationAccess _map(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine =>
        LocationAccess.denied,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
    };
  }
}
