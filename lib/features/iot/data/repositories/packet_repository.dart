import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/data/repository.dart';
import '../../models/network_models.dart';
import '../../models/packet.dart';
import '../dummy_network.dart';

/// Data-layer access point for [Packet] records and network telemetry.
///
/// Groups the transmission log, gateway/repeater nodes and the aggregate
/// network snapshot behind one repository, since they all describe the same
/// IoT transport concern.
abstract interface class PacketRepository
    implements ReadableRepository<Packet> {
  /// The current aggregate network snapshot.
  Future<NetworkStatus> networkStatus();

  /// Every registered gateway and repeater node.
  Future<List<MeshNode>> nodes();
}

/// Dummy implementation backed by [DummyNetwork].
class DummyPacketRepository implements PacketRepository {
  const DummyPacketRepository();

  @override
  String get name => 'DummyPacketRepository';

  @override
  Future<List<Packet>> fetchAll() async {
    // Derive hop counts from the transport so the seeded packets carry the
    // same field set as live traffic will in a later phase.
    return DummyNetwork.packetLogJson.map((Map<String, dynamic> json) {
      final LinkMode transport =
          LinkMode.values.byName(json['transport'] as String);
      final int hops = switch (transport) {
        LinkMode.loRa => 2,
        LinkMode.mesh => 3,
        LinkMode.internet => 1,
        LinkMode.offline => 0,
      };
      return Packet.fromJson(<String, dynamic>{...json, 'hopCount': hops});
    }).toList();
  }

  @override
  Future<NetworkStatus> networkStatus() async => DummyNetwork.status;

  @override
  Future<List<MeshNode>> nodes() async => DummyNetwork.nodes;
}

/// Provides the active [PacketRepository] implementation.
final Provider<PacketRepository> packetRepositoryProvider =
    Provider<PacketRepository>((Ref ref) => const DummyPacketRepository());
