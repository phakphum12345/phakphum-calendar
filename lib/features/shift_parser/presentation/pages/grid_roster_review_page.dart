import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/entities/shift_template.dart';
import '../../application/grid_roster_canonical_converter.dart';
import '../../application/grid_roster_import_workflow.dart';
import '../../application/grid_roster_review_session.dart';

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
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reviewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.contextSnapshot.session;
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
                            if (section.assessment.section.startDate != null &&
                                section.assessment.section.endDate != null)
                              Text(
                                'ช่วงวันที่: '
                                '${_date(section.assessment.section.startDate!)}'
                                ' – '
                                '${_date(section.assessment.section.endDate!)}',
                              ),
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

  Widget _buildAssignmentCard(
    BuildContext context,
    GridRosterAssignmentReview review,
  ) {
    final source = review.source;
    final sourceId = GridRosterCanonicalConverter.assignmentId(
      widget.contextSnapshot.session.sourceFingerprint,
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
            rule.isResolved
                ? 'กะที่ตรวจพบ: ${rule.code} '
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
                labelText: rule.isResolved
                    ? 'เลือก Template อื่น (ไม่บังคับ)'
                    : 'เลือก Template เพื่อระบุกะ',
                helperText: rule.isResolved
                    ? 'เว้นว่างเพื่อใช้กฎที่ตรวจพบ'
                    : 'จำเป็นสำหรับการนำเข้ารายการนี้',
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

    final decisions = <String, GridRosterAssignmentDecision>{};
    final reviewedAt = DateTime.now().toUtc();
    var includedCount = 0;
    for (final review in widget.contextSnapshot.session.assignments) {
      final sourceId = GridRosterCanonicalConverter.assignmentId(
        widget.contextSnapshot.session.sourceFingerprint,
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
      context: widget.contextSnapshot,
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
      context: widget.contextSnapshot,
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
