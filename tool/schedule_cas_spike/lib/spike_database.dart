import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'spike_database.g.dart';

class ScheduleRecords extends Table {
  TextColumn get scheduleId => text()();
  IntColumn get generation => integer()();
  TextColumn get state => text()();
  TextColumn get payload => text().nullable()();
  TextColumn get fingerprint => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scheduleId};
}

@DriftDatabase(tables: [ScheduleRecords])
class SpikeDatabase extends _$SpikeDatabase {
  SpikeDatabase(super.executor);

  factory SpikeDatabase.forApplication() {
    return SpikeDatabase(
      driftDatabase(
        name: 'schedule_cas_spike',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.dart.js'),
        ),
      ),
    );
  }

  @override
  int get schemaVersion => 1;
}
