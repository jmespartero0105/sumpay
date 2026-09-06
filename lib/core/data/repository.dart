/// Marker interface for the SUMPAY data layer.
///
/// Every feature exposes a repository that mediates between the presentation
/// layer (Riverpod controllers) and the underlying data sources — currently
/// in-memory dummy data seeded into SQLite. Keeping a shared contract makes the
/// Clean Architecture boundary explicit and gives a single place to document
/// the pattern the whole codebase follows.
abstract interface class Repository {
  /// A short, human-readable name used in diagnostics and logging.
  String get name;
}

/// Repositories that expose a read-all operation over a collection of [T].
abstract interface class ReadableRepository<T> implements Repository {
  /// Returns every record currently held by this repository.
  Future<List<T>> fetchAll();
}
