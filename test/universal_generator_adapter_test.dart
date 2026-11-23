import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/universal_generator_adapter/application/generator_calendar_adapter.dart';
import 'package:phakphum_calendar/features/universal_generator_adapter/domain/generator_event_record.dart';

void main() {
  const adapter = GeneratorCalendarAdapter();

  GeneratorEventRecord validRecord({
    String id = 'row-17',
    String title = 'เวรบ่าย - ภาคภูมิ',
    String start = '2026-11-06T16:30:00+07:00',
    String end = '2026-11-06T20:00:00+07:00',
  }) => GeneratorEventRecord(
    sourceRecordId: id,
    title: title,
    startIso8601: start,
    endIso8601: end,
  );

  group('GeneratorCalendarAdapter preview', () {
    test('maps explicit records without invoking Calendar sync', () {
      final preview = adapter.preview(
        GeneratorEventBatch(batchId: 'batch-001', records: [validRecord()]),
      );

      expect(preview.isReady, isTrue);
      expect(preview.requiresUserConfirmation, isTrue);
      expect(preview.candidates, hasLength(1));
      expect(
        preview.candidates.single.syncId,
        'universal-generator:batch-001:row-17',
      );
      expect(preview.candidates.single.title, 'เวรบ่าย - ภาคภูมิ');
      expect(preview.candidates.single.shouldExist, isTrue);
    });

    test('blocks records with missing stable IDs', () {
      final preview = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [validRecord(id: ' ')],
        ),
      );

      expect(preview.hasBlockingIssues, isTrue);
      expect(preview.candidates, isEmpty);
      expect(preview.issues.single.code, 'SOURCE_RECORD_ID_REQUIRED');
    });

    test('blocks duplicate source IDs rather than guessing identity', () {
      final preview = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [validRecord(), validRecord(title: 'second')],
        ),
      );

      expect(preview.hasBlockingIssues, isTrue);
      expect(preview.candidates, hasLength(1));
      expect(preview.issues.single.code, 'DUPLICATE_SOURCE_RECORD_ID');
    });

    test('blocks invalid or reversed date ranges', () {
      final invalidDate = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [validRecord(start: 'not-a-date')],
        ),
      );
      final reversed = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [
            validRecord(
              start: '2026-11-06T20:00:00+07:00',
              end: '2026-11-06T16:30:00+07:00',
            ),
          ],
        ),
      );

      expect(invalidDate.hasBlockingIssues, isTrue);
      expect(invalidDate.issues.single.code, 'INVALID_EVENT_DATETIME');
      expect(reversed.hasBlockingIssues, isTrue);
      expect(reversed.issues.single.code, 'INVALID_EVENT_RANGE');
    });

    test('blocks date-times without explicit timezone information', () {
      final missingStartTimezone = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [
            validRecord(start: '2026-11-06T16:30:00'),
          ],
        ),
      );
      final missingEndTimezone = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [
            validRecord(end: '2026-11-06T20:00:00'),
          ],
        ),
      );

      expect(missingStartTimezone.hasBlockingIssues, isTrue);
      expect(
        missingStartTimezone.issues.single.code,
        'INVALID_EVENT_DATETIME',
      );
      expect(missingEndTimezone.hasBlockingIssues, isTrue);
      expect(missingEndTimezone.issues.single.code, 'INVALID_EVENT_DATETIME');
    });

    test('accepts UTC Z timestamps', () {
      final preview = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [
            validRecord(
              start: '2026-11-06T09:30:00Z',
              end: '2026-11-06T13:00:00Z',
            ),
          ],
        ),
      );

      expect(preview.isReady, isTrue);
      expect(preview.candidates.single.start.isUtc, isTrue);
    });

    test('encodes ID components so delimiter characters cannot collide', () {
      final first = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch:a',
          records: [validRecord(id: 'b')],
        ),
      );
      final second = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch',
          records: [validRecord(id: 'a:b')],
        ),
      );

      expect(first.isReady, isTrue);
      expect(second.isReady, isTrue);
      expect(
        first.candidates.single.syncId,
        isNot(second.candidates.single.syncId),
      );
    });

    test('blocks an empty event title', () {
      final preview = adapter.preview(
        GeneratorEventBatch(
          batchId: 'batch-001',
          records: [validRecord(title: ' ')],
        ),
      );

      expect(preview.hasBlockingIssues, isTrue);
      expect(preview.candidates, isEmpty);
      expect(preview.issues.single.code, 'EVENT_TITLE_REQUIRED');
    });

    test('blocks an empty batch', () {
      final preview = adapter.preview(
        const GeneratorEventBatch(batchId: 'batch-001', records: []),
      );

      expect(preview.hasBlockingIssues, isTrue);
      expect(preview.isReady, isFalse);
      expect(preview.candidates, isEmpty);
      expect(preview.issues.single.code, 'EMPTY_BATCH');
    });

    test('blocks an empty batch identifier', () {
      final preview = adapter.preview(
        GeneratorEventBatch(batchId: ' ', records: [validRecord()]),
      );

      expect(preview.hasBlockingIssues, isTrue);
      expect(preview.candidates, isEmpty);
      expect(preview.issues.single.code, 'BATCH_ID_REQUIRED');
    });
  });
}
