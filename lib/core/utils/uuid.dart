import 'dart:math';

/// Minimal RFC-4122 version-4 UUID generator.
///
/// SUMPAY avoids adding a `uuid` package dependency for a single use; this
/// produces standard random UUIDs suitable for packet identifiers and the
/// per-install device id. Uses [Random.secure] so identifiers do not collide
/// across devices in practice.
class Uuid {
  const Uuid._();

  static final Random _random = Random.secure();

  /// Returns a new random UUID string, e.g. `3f2504e0-4f89-41d3-9a0c-0305e82c3301`.
  static String v4() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version (4) and variant (10xx) bits per RFC 4122.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex =
        bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
