/// A normalized event record received from the Universal Generator.
///
/// This contract is deliberately independent from the legacy Excel reader,
/// roster parser, repositories and Google Calendar gateways.
class GeneratorEventRecord {
  const GeneratorEventRecord({
    required this.sourceRecordId,
    required this.title,
    required this.startIso8601,
    required this.endIso8601,
    this.description,
  });

  final String sourceRecordId;
  final String title;
  final String startIso8601;
  final String endIso8601;
  final String? description;
}

/// One reviewed batch exported by the Universal Generator.
class GeneratorEventBatch {
  const GeneratorEventBatch({
    required this.batchId,
    required this.records,
  });

  final String batchId;
  final List<GeneratorEventRecord> records;
}
