import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/location_permission_handler.dart';
import '../data/services/location_service.dart';
import '../models/sos_location_model.dart';

/// State of the on-demand location capture used by the SOS flow.
class LocationCaptureState {
  const LocationCaptureState({
    this.isCapturing = false,
    this.location,
    this.failure,
  });

  final bool isCapturing;

  /// The most recently captured fix, if any.
  final SosLocationModel? location;

  /// Why the last attempt failed, if it did.
  final LocationFailure? failure;

  bool get hasLocation => location != null;

  LocationCaptureState copyWith({
    bool? isCapturing,
    SosLocationModel? location,
    LocationFailure? failure,
    bool clearFailure = false,
  }) {
    return LocationCaptureState(
      isCapturing: isCapturing ?? this.isCapturing,
      location: location ?? this.location,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Drives one-shot location capture for the SOS screen.
///
/// Location is only ever read when [capture] is invoked (when the resident is
/// preparing or sending an SOS). There is no streaming or background updating.
class LocationController extends StateNotifier<LocationCaptureState> {
  LocationController(this._service) : super(const LocationCaptureState());

  final LocationService _service;

  LocationPermissionHandler get permissions => _service.permissions;

  /// Captures the current position, updating state with the fix or the failure.
  Future<SosLocationModel?> capture() async {
    state = state.copyWith(isCapturing: true, clearFailure: true);
    final LocationResult result = await _service.capture();
    if (result.isSuccess) {
      state = state.copyWith(
        isCapturing: false,
        location: result.location,
        clearFailure: true,
      );
      return result.location;
    }
    state = state.copyWith(isCapturing: false, failure: result.failure);
    return null;
  }

  /// Clears the captured location (e.g. when leaving the SOS screen).
  void reset() {
    state = const LocationCaptureState();
  }
}

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) => const LocationService());

final StateNotifierProvider<LocationController, LocationCaptureState>
    locationProvider =
    StateNotifierProvider<LocationController, LocationCaptureState>(
  (Ref ref) => LocationController(ref.watch(locationServiceProvider)),
);
