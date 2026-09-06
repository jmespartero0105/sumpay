import '../../models/mesh_packet.dart';

/// The kind of underlying link a transport uses. Mirrors [LinkMode] but kept
/// local to the transport layer so transports can be reasoned about
/// independently of the display enum.
enum TransportKind { mesh, internet, loRa }

/// Connection state a transport can report, kept deliberately simple so the
/// [TransportManager] and network status can combine them without ambiguity.
enum TransportStatus { connected, connecting, disconnected }

/// A packet that arrived over some transport, tagged with which transport
/// delivered it so the manager can de-duplicate across paths (a packet may
/// arrive over both the internet and the mesh).
class TransportInbound {
  const TransportInbound({
    required this.packet,
    required this.via,
  });

  final MeshPacket packet;
  final TransportKind via;
}

/// Common contract implemented by every SUMPAY transport (mesh today, internet
/// in this phase, LoRa later). The application and routing layers depend only
/// on this interface, never on a concrete transport, so new transports can be
/// added without touching messaging, SOS, broadcast or responder code.
abstract class SumpayTransport {
  /// Which kind of link this transport represents.
  TransportKind get kind;

  /// Current connection state of this transport.
  TransportStatus get status;

  /// Emits connection-state changes for this transport.
  Stream<TransportStatus> get statusStream;

  /// Emits packets received over this transport.
  Stream<TransportInbound> get inbound;

  /// Whether this transport is currently able to send.
  bool get isAvailable => status == TransportStatus.connected;

  /// Sends a packet over this transport. Implementations should not throw for
  /// ordinary unavailability; they should surface it via [status] and, where
  /// appropriate, queue. Throwing is reserved for genuine send failures.
  Future<void> send(MeshPacket packet);

  /// Starts the transport (connect, subscribe, begin advertising, etc.).
  Future<void> start();

  /// Stops the transport and releases resources.
  Future<void> dispose();
}
