import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback fired when a peer endpoint is discovered.
typedef EndpointFound = void Function(
  String endpointId,
  String endpointName,
  String serviceId,
);

/// Callback fired when a previously discovered endpoint is lost.
typedef EndpointLost = void Function(String endpointId);

/// Callback fired when a connection handshake is initiated (either direction).
typedef ConnectionInitiated = void Function(
  String endpointId,
  String endpointName,
  String authenticationToken,
  bool isIncoming,
);

/// Callback fired with the result of a connection attempt.
typedef ConnectionResult = void Function(String endpointId, bool accepted);

/// Callback fired when an endpoint disconnects.
typedef EndpointDisconnected = void Function(String endpointId);

/// A raw bytes payload received from a connected endpoint.
class ReceivedPayload {
  const ReceivedPayload({required this.endpointId, required this.bytes});

  final String endpointId;
  final List<int> bytes;
}

/// Thin wrapper around the `nearby_connections` plugin.
///
/// Isolates every plugin call behind a small, testable surface so the provider
/// and UI never import the plugin directly. Phase 2 covers permissions,
/// advertising, discovery, connecting and disconnecting only — no payloads are
/// sent, in line with "do not implement messaging yet". The accept-connection
/// step registers no-op payload handlers purely to satisfy the plugin contract.
class NearbyService {
  NearbyService({
    this.serviceId = _defaultServiceId,
    Strategy strategy = Strategy.P2P_CLUSTER,
  }) : _strategy = strategy;

  static const String _defaultServiceId = 'com.sumpay.app';

  final String serviceId;
  final Strategy _strategy;

  // The nearby_connections plugin is mobile-only. Instantiate lazily so it is
  // NEVER created on web (where the plugin has no implementation and would throw
  // MissingPluginException on its event channel).
  Nearby? _nearbyInstance;
  Nearby get _nearby => _nearbyInstance ??= Nearby();

  /// Broadcasts every bytes payload received from any connected endpoint.
  final StreamController<ReceivedPayload> _payloadController =
      StreamController<ReceivedPayload>.broadcast();

  /// Stream of inbound bytes payloads. The transport layer listens to this.
  Stream<ReceivedPayload> get onPayloadReceived => _payloadController.stream;

  bool _advertising = false;
  bool _discovering = false;

  bool get isAdvertising => _advertising;
  bool get isDiscovering => _discovering;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// The full set of permissions Nearby Connections may need. Which ones the OS
  /// actually surfaces depends on the Android version — several are silently
  /// ignored (and report non-granted) on versions where they do not apply, so
  /// they must NOT all be required. See [_isSatisfied].
  static const List<Permission> _allPermissions = <Permission>[
    Permission.location,
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.nearbyWifiDevices,
  ];

  /// A permission counts as satisfied when the OS has granted it, granted a
  /// limited/provisional form of it, or restricted it (parental controls) — the
  /// latter cannot be changed by the user, so blocking on it is pointless.
  bool _isSatisfied(PermissionStatus status) =>
      status.isGranted ||
      status.isLimited ||
      status.isProvisional ||
      status.isRestricted;

  /// Determines whether the app has enough permission to run Nearby.
  ///
  /// This does NOT require every entry in [_allPermissions]. Android versions
  /// differ in which permissions exist:
  ///  - API 31 (Android 12): needs the Bluetooth runtime trio + location; the
  ///    legacy [Permission.bluetooth] and API-33 [Permission.nearbyWifiDevices]
  ///    report non-granted and must be ignored.
  ///  - API 33+ (Android 13+): needs the Bluetooth trio; location is optional
  ///    and [Permission.nearbyWifiDevices] replaces it.
  ///  - API <31 (Android 11-): needs location; the new Bluetooth permissions do
  ///    not exist and report non-granted.
  ///
  /// So the rule that holds across every version is: the Bluetooth runtime trio
  /// (when the OS surfaces them) must be granted, AND at least one of
  /// location / nearbyWifiDevices must be granted. We evaluate that from the
  /// live statuses rather than hard-coding an API level.
  Future<bool> _evaluateGranted() async {
    final Map<Permission, PermissionStatus> statuses =
        <Permission, PermissionStatus>{
      for (final Permission p in _allPermissions) p: await p.status,
    };

    // Dev-only: surfaces the raw per-permission status so a false "denied" can
    // be traced to the exact permission responsible.
    if (kDebugMode) {
      debugPrint('Nearby permission statuses: '
          '${statuses.map((Permission p, PermissionStatus s) => MapEntry<String, String>(p.toString(), s.toString()))}');
    }

    bool ok(Permission p) => _isSatisfied(statuses[p]!);

    // The three Android-12+ Bluetooth runtime permissions. On older versions
    // these are reported as denied/not-applicable; there, location carries the
    // requirement instead, so we only enforce the trio when at least one of
    // them is actually granted (i.e. the OS supports them).
    final bool btSupported = ok(Permission.bluetoothScan) ||
        ok(Permission.bluetoothConnect) ||
        ok(Permission.bluetoothAdvertise);
    final bool btOk = !btSupported ||
        (ok(Permission.bluetoothScan) &&
            ok(Permission.bluetoothConnect) &&
            ok(Permission.bluetoothAdvertise));

    // Proximity requirement: satisfied by location (older OS) OR the Android-13+
    // nearby-wifi permission.
    final bool proximityOk =
        ok(Permission.location) || ok(Permission.nearbyWifiDevices);

    return btOk && proximityOk;
  }

  /// Returns `true` when the app already holds enough permission to run Nearby.
  Future<bool> hasPermissions() => _evaluateGranted();

  /// Requests every applicable runtime permission and reports whether the app
  /// now holds enough to run Nearby.
  ///
  /// The full set is requested — the OS silently skips permissions that do not
  /// apply to the running version — and success is judged by [_evaluateGranted]
  /// rather than by requiring literally every permission, so inapplicable
  /// permissions never cause a false "denied".
  Future<bool> requestPermissions() async {
    await _allPermissions.request();
    return _evaluateGranted();
  }

  /// Whether location services (GPS) are enabled — Nearby is unreliable without
  /// them on many devices.
  Future<bool> isLocationEnabled() async {
    final ServiceStatus status = await Permission.location.serviceStatus;
    return status.isEnabled;
  }

  // ---------------------------------------------------------------------------
  // Advertising
  // ---------------------------------------------------------------------------

  /// Begins advertising this device to nearby discoverers.
  Future<bool> startAdvertising({
    required String deviceName,
    required ConnectionInitiated onConnectionInitiated,
    required ConnectionResult onConnectionResult,
    required EndpointDisconnected onDisconnected,
  }) async {
    if (kIsWeb) return false; // mesh is mobile-only
    if (_advertising) return true;
    try {
      final bool started = await _nearby.startAdvertising(
        deviceName,
        _strategy,
        serviceId: serviceId,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          onConnectionInitiated(
            id,
            info.endpointName,
            info.authenticationToken,
            info.isIncomingConnection,
          );
        },
        onConnectionResult: (String id, Status status) {
          onConnectionResult(id, status == Status.CONNECTED);
        },
        onDisconnected: onDisconnected,
      );
      _advertising = started;
      return started;
    } catch (error, stack) {
      debugPrint('NearbyService.startAdvertising failed: $error\n$stack');
      _advertising = false;
      rethrow;
    }
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    try {
      await _nearby.stopAdvertising();
    } finally {
      _advertising = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Begins discovering nearby advertisers.
  Future<bool> startDiscovery({
    required String deviceName,
    required EndpointFound onEndpointFound,
    required EndpointLost onEndpointLost,
  }) async {
    if (kIsWeb) return false; // mesh is mobile-only
    if (_discovering) return true;
    try {
      final bool started = await _nearby.startDiscovery(
        deviceName,
        _strategy,
        serviceId: serviceId,
        onEndpointFound: (String id, String name, String service) {
          onEndpointFound(id, name, service);
        },
        onEndpointLost: (String? id) {
          if (id != null) onEndpointLost(id);
        },
      );
      _discovering = started;
      return started;
    } catch (error, stack) {
      debugPrint('NearbyService.startDiscovery failed: $error\n$stack');
      _discovering = false;
      rethrow;
    }
  }

  /// Stops discovery. Already-discovered endpoints remain connectable.
  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    try {
      await _nearby.stopDiscovery();
    } finally {
      _discovering = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------------

  /// Requests a connection to a discovered [endpointId].
  Future<void> requestConnection({
    required String deviceName,
    required String endpointId,
    required ConnectionInitiated onConnectionInitiated,
    required ConnectionResult onConnectionResult,
    required EndpointDisconnected onDisconnected,
  }) async {
    try {
      await _nearby.requestConnection(
        deviceName,
        endpointId,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          onConnectionInitiated(
            id,
            info.endpointName,
            info.authenticationToken,
            info.isIncomingConnection,
          );
        },
        onConnectionResult: (String id, Status status) {
          onConnectionResult(id, status == Status.CONNECTED);
        },
        onDisconnected: onDisconnected,
      );
    } catch (error, stack) {
      debugPrint('NearbyService.requestConnection failed: $error\n$stack');
      rethrow;
    }
  }

  /// Accepts an initiated connection and begins listening for byte payloads.
  ///
  /// Received BYTES payloads are forwarded to [onPayloadReceived]; the transport
  /// layer decodes them into chat messages. Transfer-status updates are ignored
  /// because BYTES payloads always arrive complete in a single callback.
  Future<void> acceptConnection(String endpointId) async {
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (String endpointId, Payload payload) {
          if (payload.type == PayloadType.BYTES && payload.bytes != null) {
            _payloadController.add(
              ReceivedPayload(
                endpointId: endpointId,
                bytes: payload.bytes!,
              ),
            );
          }
        },
        onPayloadTransferUpdate:
            (String endpointId, PayloadTransferUpdate update) {
          // BYTES payloads are delivered whole in onPayLoadRecieved, so no
          // per-chunk handling is needed here.
        },
      );
    } catch (error, stack) {
      debugPrint('NearbyService.acceptConnection failed: $error\n$stack');
      rethrow;
    }
  }

  /// Sends a raw byte payload to a connected [endpointId].
  Future<void> sendBytes(String endpointId, List<int> bytes) async {
    try {
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(bytes),
      );
    } catch (error, stack) {
      debugPrint('NearbyService.sendBytes failed: $error\n$stack');
      rethrow;
    }
  }

  /// Rejects an initiated connection.
  Future<void> rejectConnection(String endpointId) async {
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (error, stack) {
      debugPrint('NearbyService.rejectConnection failed: $error\n$stack');
      rethrow;
    }
  }

  /// Disconnects from a single connected [endpointId].
  Future<void> disconnect(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
    } catch (error, stack) {
      debugPrint('NearbyService.disconnect failed: $error\n$stack');
      rethrow;
    }
  }

  /// Disconnects from every connected endpoint.
  Future<void> disconnectAll() async {
    try {
      await _nearby.stopAllEndpoints();
    } catch (error, stack) {
      debugPrint('NearbyService.disconnectAll failed: $error\n$stack');
      rethrow;
    }
  }

  /// Tears down advertising, discovery and all connections. Call on dispose.
  Future<void> shutdown() async {
    await stopAdvertising();
    await stopDiscovery();
    await disconnectAll();
    await _payloadController.close();
  }
}
