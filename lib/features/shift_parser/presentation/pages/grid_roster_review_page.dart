import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/entities/shift_template.dart';
import '../../application/grid_roster_canonical_converter.dart';
import '../../application/grid_roster_import_workflow.dart';
import '../../application/grid_roster_review_session.dart';
import '../../application/monthly_roster_section_parser.dart';
import '../../domain/monthly_roster_section.dart';
import '../../domain/roster_grid_axis_mapping.dart';
import '../../domain/shift_parser_input.dart';

/// Human review screen for a parsed multi-sheet Grid workbook.
///
/// No assignment is included by default. The reviewer must select each
/// employee and explicitly opt in before the canonical commit can proceed.
class GridRosterReviewPage extends StatefulWidget {
  const GridRosterReviewPage({
    required this.workflow,
    required this.contextSnapshot,
    required this.employees,
    required this.shiftTemplates,
    super.key,
  });

  final GridRosterImportWorkflow workflow;
  final GridRosterImportReviewContext contextSnapshot;
  final List<Employee> employees;
  final List<ShiftTemplate> shiftTemplates;

  @override
  State<GridRosterReviewPage> createState() => _GridRosterReviewPageState();
}

class _GridRosterReviewPageState extends State<GridRosterReviewPage> {
  final _reviewerController = TextEditingController();
  final Map<String, bool> _included = {};
  final Map<String, String?> _selectedEmployees = {};
  final Map<String, String?> _selectedTemplates = {};
  final Map<String, String> _dateAnomalyChoices = {};
  late GridRosterImportReviewContext _reviewContext;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewContext = widget.contextSnapshot;
  }

  @override
  void dispose() {
    _reviewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _reviewContext.session;
    final assignmentCount = session.assignments.length;
    final includedCount = _included.values.where((value) => value).length;

    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบตารางเวรแบบ Grid')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workbook review',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('จำนวน Worksheet ที่สแกน: ${session.sourceSheetCount}'),
                          Text('จำนวน Section: ${session.sections.length}'),
                          Text('จำนวนรายการ: $assignmentCount'),
                          Text(
                            'รายการที่เลือกนำเข้า: $includedCount',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Target: ${session.targetScheduleId} • '
                            '${session.targetScheduleRevision}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reviewerController,
                            decoration: const InputDecoration(
                              labelText: 'รหัสหรือชื่อผู้ตรวจสอบ',
                              helperText:
                                  'บันทึกเป็นข้อมูลที่ผู้ตรวจสอบระบุเอง ยังไม่ใช่การยืนยันตัวตน',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (session.warnings.isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Worksheet ที่อ่านไม่ครบหรือมีคำเตือน',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            for (final warning in session.warnings)
                              Text(warning),
                          ],
                        ),
                      ),
                    ),
                  for (final section in session.sections) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.assessment.section.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'สถานะ: ${section.assessment.readiness.name}',
                            ),
                            if (section.assessment.section.sourceCells.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<RosterGridOrientation>(
                                key: ValueKey(
                                  'grid-roster-orientation-${section.assessment.section.sourceSheetId ?? 'local'}-${section.assessment.section.headerRowIndex}-${section.assessment.section.title}',
                                ),
                                initialValue: section.assessment.section.orientation,
                                decoration: const InputDecoration(
                                  labelText: 'แนววันที่ของ Section นี้',
                                  helperText:
                                      'เปลี่ยนได้เมื่อระบบตรวจจับไม่ตรงกับไฟล์ต้นฉบับ ระบบจะอ่านข้อมูลต้นฉบับใหม่และล้างตัวเลือกเดิม',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: RosterGridOrientation.datesAcrossColumns,
                                    child: Text('วันที่เรียงตามคอลัมน์'),
                                  ),
                                  DropdownMenuItem(
                                    value: RosterGridOrientation.datesDownRows,
                                    child: Text('วันที่เรียงตามแถว'),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _selectOrientation(
                                            section.assessment.section,
                                            value,
                                          );
                                        }
                                      },
                              ),
                            ],
                            if (section.assessment.section.startDate != null &&
                                section.assessment.section.endDate != null)
                              Text(
                                'ช่วงวันที่: '
                                '${_date(section.assessment.section.startDate!)}'
                                ' – '
                                '${_date(section.assessment.section.endDate!)}',
                              ),
                            if (section.assessment.section.dateAnomalies.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'พบจุดผิดในหัวตารางวันที่',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              for (final anomaly
                                  in section.assessment.section.dateAnomalies)
                                _buildDateAnomalyCard(
                                  context,
                                  section.assessment.section,
                                  anomaly,
                                ),
                              Text(
                                _sectionDateChoiceLabel(
                                  section.assessment.section,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            for (final reason in section.assessment.reasonCodes)
                              Text(
                                '• $reason',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (section.assignments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('ไม่มีรายการเวรใน Section นี้'),
                              ),
                            for (final review in section.assignments)
                              _buildAssignmentCard(context, review),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _commit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _saving
                        ? 'กำลังตรวจสอบและบันทึก...'
                        : 'ยืนยันรายการที่เลือกและบันทึก',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateAnomalyKey(
    MonthlyRosterSection section,
    MonthlyRosterDateAnomaly anomaly,
  ) => [
    section.sourceSpreadsheetId ?? '',
    section.sourceSheetId?.toString() ?? '',
    section.sourceSheetTitle ?? '',
    section.title,
    section.headerRowIndex.toString(),
    anomaly.code,
    anomaly.columnIndex?.toString() ?? '-1',
    anomaly.rowIndex?.toString() ?? '-1',
    anomaly.displayedDay?.toString() ?? '',
    anomaly.message,
  ].join('|');

  String _sectionDateChoiceLabel(MonthlyRosterSection section) {
    final choices = section.dateAnomalies
        .map((anomaly) => _dateAnomalyChoices[_dateAnomalyKey(section, anomaly)])
        .toList(growable: false);
    if (choices.isNotEmpty && choices.every((choice) => choice == 'skip')) {
      return 'เลือกแล้ว: ข้าม Section นี้ทั้งส่วน จะไม่นำรายการเวรในส่วนนี้เข้า Schedule';
    }
    if (choices.any((choice) => choice == 'reimport')) {
      return 'เลือกแล้ว: กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่ — ยังบันทึก Section นี้ไม่ได้';
    }
    return 'ยังไม่ได้เลือกวิธีจัดการครบทุกข้อ — Section นี้ยังถูกบล็อก';
  }

  Widget _buildDateAnomalyCard(
    BuildContext context,
    MonthlyRosterSection section,
    MonthlyRosterDateAnomaly anomaly,
  ) {
    final key = _dateAnomalyKey(section, anomaly);
    final choice = _dateAnomalyChoices[key];
    final isVertical =
        section.orientation == RosterGridOrientation.datesDownRows;
    final axisIndex = isVertical ? anomaly.rowIndex : anomaly.columnIndex;
    final location = [
      if (section.sourceSheetTitle?.isNotEmpty ?? false)
        'ชีต ${section.sourceSheetTitle}',
      'แถวแกนวันที่ ${section.headerRowIndex + 1}',
      if (axisIndex != null)
        isVertical ? 'แถววันที่ ${axisIndex + 1}' : 'คอลัมน์วันที่ ${axisIndex + 1}',
      if (anomaly.displayedDay != null) 'เลขวันที่ ${anomaly.displayedDay}',
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(anomaly.code, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(location),
          Text(anomaly.message),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _chooseDateAnomalyAction(section, anomaly),
                icon: const Icon(Icons.tune),
                label: Text(choice == null ? 'เลือกวิธีจัดการ' : 'เปลี่ยนตัวเลือก'),
              ),
              if (axisIndex != null &&
                  section.sourceCells.isNotEmpty &&
                  section.startDate != null &&
                  section.endDate != null)
                TextButton.icon(
                  key: ValueKey(
                    'grid-roster-correct-date-${section.sourceSheetId ?? 'local'}-${section.headerRowIndex}-$axisIndex-${anomaly.code}',
                  ),
                  onPressed: () =>
                      _correctDateAxis(section, axisIndex, isVertical),
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(
                    isVertical ? 'กำหนดวันที่แถวนี้' : 'กำหนดวันที่คอลัมน์นี้',
                  ),
                ),
              if (choice != null)
                Text(
                  choice == 'skip' ? 'เลือกข้าม Section' : 'เลือกแก้ต้นฉบับ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectOrientation(
    MonthlyRosterSection section,
    RosterGridOrientation orientation,
  ) async {
    if (_saving || orientation == section.orientation) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันเปลี่ยนแนววันที่'),
        content: const Text(
          'ระบบจะอ่าน Section นี้จากเซลล์ต้นฉบับอีกครั้ง ไม่บันทึก Schedule '
          'และจะล้างการเลือกพนักงาน/กะเดิมเพื่อให้ตรวจสอบใหม่ทั้งหมด',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('เปลี่ยนแนววันที่และตรวจตารางใหม่'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    try {
      if (section.sourceCells.isEmpty) {
        throw StateError('ไม่พบเซลล์ต้นฉบับสำหรับตรวจแนววันที่ใหม่');
      }
      final firstCell = section.sourceCells.first;
      final input = ShiftParserInput(
        spreadsheetId: section.sourceSpreadsheetId ?? '',
        spreadsheetTitle: section.sourceSheetTitle ?? section.title,
        sheetId: section.sourceSheetId ?? firstCell.sheetId,
        sheetTitle: section.sourceSheetTitle ?? firstCell.sheetTitle,
        timeZone: null,
        cells: List.unmodifiable(section.sourceCells),
      );
      final parsed = const MonthlyRosterSectionParser().parseWithOrientation(
        input,
        orientation,
      );
      if (parsed.sections.length != 1) {
        final details = parsed.warnings.isEmpty
            ? 'ไม่พบ Section ที่ตรงกับแนววันที่ที่เลือก'
            : parsed.warnings.join('\n');
        throw StateError(
          'ต้องพบ Section ที่ตีความได้เพียงหนึ่งส่วน แต่พบ ${parsed.sections.length} ส่วน: $details',
        );
      }

      final nextSections = <MonthlyRosterSection>[];
      var replaced = false;
      for (final review in _reviewContext.session.sections) {
        if (identical(review.assessment.section, section)) {
          nextSections.add(parsed.sections.single);
          replaced = true;
        } else {
          nextSections.add(review.assessment.section);
        }
      }
      if (!replaced) {
        throw StateError('ไม่พบ Section เดิมใน Review session');
      }

      final currentSession = _reviewContext.session;
      final report = MonthlyRosterParseReport(
        sections: List.unmodifiable(nextSections),
        warnings: List.unmodifiable([
          ...currentSession.warnings,
          ...parsed.warnings,
        ]),
        sourceSheetCount: currentSession.sourceSheetCount,
        sourceFingerprint: currentSession.sourceFingerprint,
      );
      final nextSession = widget.workflow.reviewSessionBuilder.build(
        report: report,
        employees: widget.employees,
        shiftTemplates: widget.shiftTemplates,
        sourceFingerprint: currentSession.sourceFingerprint,
        targetScheduleId: currentSession.targetScheduleId,
        targetScheduleRevision: currentSession.targetScheduleRevision,
      );
      setState(() {
        _reviewContext = GridRosterImportReviewContext(
          session: nextSession,
          targetSchedule: _reviewContext.targetSchedule,
          targetExisted: _reviewContext.targetExisted,
        );
        _included.clear();
        _selectedEmployees.clear();
        _selectedTemplates.clear();
        _dateAnomalyChoices.clear();
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'เปลี่ยนแนววันที่ไม่ได้: $error';
      });
    }
  }

  Future<void> _correctDateAxis(
    MonthlyRosterSection section,
    int axisIndex,
    bool isVertical,
  ) async {
    final start = section.startDate;
    final end = section.endDate;
    if (start == null || end == null || section.sourceCells.isEmpty) return;
    var initialDate = DateTime(start.year, start.month, start.day);
    for (final column in section.dateColumns) {
      if (isVertical
          ? column.rowIndex == axisIndex
          : column.columnIndex == axisIndex) {
        initialDate = column.date;
        break;
      }
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: DateTime(end.year, end.month, end.day),
      helpText: isVertical
          ? 'เลือกวันที่จริงของแถว ${axisIndex + 1}'
          : 'เลือกวันที่จริงของคอลัมน์ ${axisIndex + 1}',
      confirmText: 'ใช้วันที่นี้และตรวจตารางใหม่',
    );
    if (!mounted || selected == null) return;

    try {
      final parser = const MonthlyRosterSectionParser();
      final corrected = isVertical
          ? parser.correctDateRows(
              section: section,
              correctedDatesByRow: {axisIndex: selected},
            )
          : parser.correctDateColumns(
              section: section,
              correctedDatesByColumn: {axisIndex: selected},
            );
      final sections = _reviewContext.session.sections
          .map((review) {
            final current = review.assessment.section;
            if (current.headerRowIndex == section.headerRowIndex &&
                current.sourceSheetId == section.sourceSheetId &&
                current.sourceSheetTitle == section.sourceSheetTitle &&
                current.title == section.title) {
              return corrected;
            }
            return current;
          })
          .toList(growable: false);
      final report = MonthlyRosterParseReport(
        sections: sections,
        warnings: _reviewContext.session.warnings,
        sourceSheetCount: _reviewContext.session.sourceSheetCount,
        sourceFingerprint: _reviewContext.session.sourceFingerprint,
      );
      final nextSession = widget.workflow.reviewSessionBuilder.build(
        report: report,
        employees: widget.employees,
        shiftTemplates: widget.shiftTemplates,
        sourceFingerprint: _reviewContext.session.sourceFingerprint,
        targetScheduleId: _reviewContext.session.targetScheduleId,
        targetScheduleRevision: _reviewContext.targetScheduleRevision,
      );
      setState(() {
        _reviewContext = GridRosterImportReviewContext(
          session: nextSession,
          targetSchedule: _reviewContext.targetSchedule,
          targetExisted: _reviewContext.targetExisted,
        );
        _dateAnomalyChoices.clear();
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'แก้วันที่ไม่ได้: $error';
      });
    }
  }

  Future<void> _chooseDateAnomalyAction(
    MonthlyRosterSection section,
    MonthlyRosterDateAnomaly anomaly,
  ) async {
    final key = _dateAnomalyKey(section, anomaly);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เลือกวิธีจัดการจุดผิด'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(anomaly.message),
            const SizedBox(height: 12),
            const Text('เลือกได้หนึ่งวิธีสำหรับข้อผิดพลาดนี้:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('reimport'),
            child: const Text('กลับไปแก้ไฟล์ต้นฉบับและนำเข้าใหม่'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop('skip'),
            child: const Text('ข้าม Section นี้ทั้งส่วน'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ยังไม่เลือก'),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _dateAnomalyChoices[key] = selected);
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    GridRosterAssignmentReview review,
  ) {
    final source = review.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      _reviewContext.session.sourceFingerprint,
      source,
    );
    final included = _included[sourceId] ?? false;
    final blocked = review.sectionBlocked;
    final rule = review.shiftRule;
    final candidateNames = review.identity.candidates
        .map((candidate) => candidate.employee.displayName)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${source.rowLabel} • ${_date(source.date)} • ${source.sourceCell}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('ชื่อจากต้นฉบับ: ${source.workerName}'),
          if (candidateNames.isNotEmpty)
            Text(
              'คำแนะนำพนักงาน: $candidateNames',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            rule.status == MonthlyRosterShiftRuleStatus.builtInRule
                ? 'คำแนะนำกะจากชื่อแถว: ${rule.code} '
                    '(${_time(rule.startTime)}–${_time(rule.endTime)}) — โปรดตรวจสอบ'
                : rule.isResolved
                ? 'กะจาก Template ที่ตั้งค่าไว้: ${rule.code} '
                    '(${_time(rule.startTime)}–${_time(rule.endTime)})'
                : 'ยังไม่พบกฎกะที่ยืนยันได้',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('นำรายการนี้เข้า Schedule'),
            subtitle: blocked
                ? const Text('Section นี้ถูกบล็อกจากปัญหาวันที่')
                : const Text('ไม่เลือก = บันทึกเป็นรายการยกเว้น'),
            value: included && !blocked,
            onChanged: blocked
                ? null
                : (value) => setState(
                    () => _included[sourceId] = value ?? false,
                  ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (included && !blocked) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedEmployees[sourceId],
              decoration: const InputDecoration(
                labelText: 'ยืนยันพนักงาน',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final employee in widget.employees.where((e) => e.active))
                  DropdownMenuItem(
                    value: employee.id,
                    child: Text(employee.displayName),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedEmployees[sourceId] = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTemplates[sourceId],
              decoration: InputDecoration(
                labelText: switch (rule.status) {
                  MonthlyRosterShiftRuleStatus.builtInRule =>
                    'เลือก Template เพื่อแทนคำแนะนำกะ (ไม่บังคับ)',
                  MonthlyRosterShiftRuleStatus.configuredTemplate =>
                    'เลือก Template อื่น (ไม่บังคับ)',
                  _ => 'เลือก Template เพื่อระบุกะ',
                },
                helperText: switch (rule.status) {
                  MonthlyRosterShiftRuleStatus.builtInRule =>
                    'เว้นว่างเพื่อใช้คำแนะนำกะนี้หลังจากยืนยันนำรายการเข้า Schedule',
                  MonthlyRosterShiftRuleStatus.configuredTemplate =>
                    'เว้นว่างเพื่อใช้ Template ที่ตั้งค่าไว้',
                  _ => 'จำเป็นสำหรับการนำเข้ารายการนี้',
                },
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final template
                    in widget.shiftTemplates.where((item) => item.active))
                  DropdownMenuItem(
                    value: template.id,
                    child: Text('${template.code} — ${template.name}'),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedTemplates[sourceId] = value),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _commit() async {
    final reviewerId = _reviewerController.text.trim();
    if (reviewerId.isEmpty) {
      setState(() => _error = 'กรุณาระบุผู้ตรวจสอบก่อนบันทึก');
      return;
    }

    for (final section in _reviewContext.session.sections) {
      final sourceSection = section.assessment.section;
      if (sourceSection.dateAnomalies.isEmpty) continue;
      final choices = sourceSection.dateAnomalies
          .map((anomaly) => _dateAnomalyChoices[_dateAnomalyKey(sourceSection, anomaly)])
          .toList(growable: false);
      if (choices.any((choice) => choice == 'reimport')) {
        setState(() => _error =
            'กรุณาแก้ไขไฟล์ต้นฉบับแล้วนำเข้าใหม่ก่อนบันทึก Section "${sourceSection.title}"');
        return;
      }
      if (choices.isEmpty || choices.any((choice) => choice != 'skip')) {
        setState(() => _error =
            'กรุณาเลือกวิธีจัดการจุดผิดวันที่ให้ครบทุกข้อใน Section "${sourceSection.title}"');
        return;
      }
    }

    final decisions = <String, GridRosterAssignmentDecision>{};
    final reviewedAt = DateTime.now().toUtc();
    var includedCount = 0;
    for (final review in _reviewContext.session.assignments) {
      final sourceId = GridRosterCanonicalConverter.assignmentId(
        _reviewContext.session.sourceFingerprint,
        review.source,
      );
      final include = (_included[sourceId] ?? false) && !review.sectionBlocked;
      final employeeId = _selectedEmployees[sourceId];
      final templateId = _selectedTemplates[sourceId];
      if (include && (employeeId == null || employeeId.isEmpty)) {
        setState(() => _error =
            'กรุณาเลือกพนักงานสำหรับรายการ ${review.source.sourceCell}');
        return;
      }
      if (include && !review.shiftRule.isResolved &&
          (templateId == null || templateId.isEmpty)) {
        setState(() => _error =
            'กรุณาเลือก Shift Template สำหรับรายการ ${review.source.sourceCell}');
        return;
      }
      if (include) includedCount++;
      decisions[sourceId] = GridRosterAssignmentDecision(
        include: include,
        employeeId: include ? employeeId : null,
        shiftTemplateId: templateId,
        reviewerId: reviewerId,
        reviewedAtUtc: reviewedAt,
      );
    }

    if (includedCount == 0) {
      setState(() => _error = 'ต้องเลือกรายการอย่างน้อย 1 รายการก่อนบันทึก');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final conversion = widget.workflow.convert(
      context: _reviewContext,
      employees: widget.employees,
      shiftTemplates: widget.shiftTemplates,
      decisions: decisions,
      importRunId: 'grid-${reviewedAt.microsecondsSinceEpoch}',
      parserVersion: 'grid-roster/1',
      createdAtUtc: reviewedAt,
    );
    if (conversion case Failure<GridRosterCanonicalConversionResult>()) {
      setState(() {
        _saving = false;
        _error = conversion.message;
      });
      return;
    }

    final converted =
        (conversion as Success<GridRosterCanonicalConversionResult>).value;
    final saved = await widget.workflow.commit(
      context: _reviewContext,
      conversion: converted,
    );
    if (!mounted) return;
    if (saved case Failure<Schedule>()) {
      setState(() {
        _saving = false;
        _error = saved.message;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _time(Duration? value) {
    if (value == null) return '--:--';
    return '${value.inHours.remainder(24).toString().padLeft(2, '0')}:'
        '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}';
  }
}
