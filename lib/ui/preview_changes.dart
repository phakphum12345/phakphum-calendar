import 'package:flutter/material.dart';
import '../controller/app_controller.dart';
import '../features/diff_engine/domain/calendar_event_candidate.dart';

enum ChangeType { add, update, delete, conflict }

class ChangeItem {
  ChangeItem({
    required this.type,
    required this.title,
    this.subtitle,
    this.oldValue,
    this.newValue,
  });

  final ChangeType type;
  final String title;
  final String? subtitle;
  final String? oldValue;
  final String? newValue;
}

class PreviewChangesPage extends StatefulWidget {
  const PreviewChangesPage({
    super.key,
    required this.controller,
    this.desiredCandidates,
  });

  final AppController controller;
  final List<CalendarEventCandidate>? desiredCandidates;

  @override
  State<PreviewChangesPage> createState() => _PreviewChangesPageState();
}

class _PreviewChangesPageState extends State<PreviewChangesPage> {
  late List<ChangeItem> items = [];
  bool loading = true;
  final Set<int> selected = {};
  List<CalendarEventCandidate> _candidateSource = [];

  @override
  Widget build(BuildContext context) {
    final adds = items.where((c) => c.type == ChangeType.add).length;
    final updates = items.where((c) => c.type == ChangeType.update).length;
    final deletes = items.where((c) => c.type == ChangeType.delete).length;
    final conflicts = items.where((c) => c.type == ChangeType.conflict).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Changes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {},
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _summaryBadge('Adds', adds, Colors.green),
                const SizedBox(width: 8),
                _summaryBadge('Updates', updates, Colors.blue),
                const SizedBox(width: 8),
                _summaryBadge('Deletes', deletes, Colors.grey),
                const SizedBox(width: 8),
                _summaryBadge('Conflicts', conflicts, Colors.red),
                const Spacer(),
                ElevatedButton(
                  onPressed: _selectAll,
                  child: const Text('Select all'),
                ),
              ],
            ),
          ),
          if (widget.controller.monthlyRosterConversion.hasUnconvertedAssignments)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'พบรายการเวรที่อ่านได้แต่ยังแปลงไม่ได้ '
                        '${widget.controller.monthlyRosterConversion.unconvertedCount} รายการ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'รายการเหล่านี้จะไม่ถูกส่งไปซิงก์ จนกว่าจะกำหนดกติกาเวรให้ถูกต้อง',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final assignment in widget.controller.monthlyRosterConversion.unconvertedAssignments.take(8))
                        Text(
                          '${assignment.date.day}/${assignment.date.month}/${assignment.date.year + 543} · '
                          '${assignment.workerName} · ${assignment.rowLabel} · ${assignment.sourceCell}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      if (widget.controller.monthlyRosterConversion.unconvertedCount > 8)
                        Text(
                          'และอีก ${widget.controller.monthlyRosterConversion.unconvertedCount - 8} รายการ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: _iconForType(item.type),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: selected.contains(index),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              selected.add(index);
                            } else {
                              selected.remove(index);
                            }
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _showDiff(context, item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text('${selected.length} selected'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Preview only'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          await _confirmAndPerformSync(selected.toList());
                        },
                  child: const Text('Apply Selected'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    // apply all items; if this is a full-plan preview, call syncCalendar
                    final all = List.generate(items.length, (i) => i);
                    await _confirmAndPerformSync(all, forceAll: true);
                  },
                  child: const Text('Apply All (force)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.desiredCandidates != null) {
      _loadCandidatePreview(widget.desiredCandidates!);
    } else {
      _loadPreview();
    }
  }

  Future<void> _loadCandidatePreview(List<CalendarEventCandidate> desired) async {
    try {
      final diff = await widget.controller.previewCandidates(desired);
      final list = <ChangeItem>[];
      _candidateSource = [];
      for (final c in diff.toAdd) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.add));
      }
      for (final c in diff.toUpdate) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.update));
      }
      for (final c in diff.toDelete) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.delete));
      }
      setState(() {
        items = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        items = [ChangeItem(type: ChangeType.conflict, title: 'ไม่สามารถเตรียม preview: $e')];
        loading = false;
      });
    }
  }

  Future<void> _loadPreview() async {
    try {
      final diff = await widget.controller.previewCalendarDiff();
      final list = <ChangeItem>[];
      _candidateSource = [];
      for (final c in diff.toAdd) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.add));
      }
      for (final c in diff.toUpdate) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.update));
      }
      for (final c in diff.toDelete) {
        _candidateSource.add(c);
        list.add(_fromCandidate(c, ChangeType.delete));
      }
      // conflicts are represented as updates that cannot synchronize; mark none by default
      setState(() {
        items = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        items = [
          ChangeItem(type: ChangeType.conflict, title: 'ไม่สามารถเตรียม preview: $e')
        ];
        loading = false;
      });
    }
  }

  ChangeItem _fromCandidate(CalendarEventCandidate c, ChangeType t) => ChangeItem(
        type: t,
        title: '${_thaiDate(c.start)} ${_time(c.start)}–${_time(c.end)} — ${c.title}',
        subtitle: c.description,
        oldValue: null,
        newValue: 'color=${c.colorId ?? 'default'}',
      );

  String _time(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _thaiDate(DateTime dt) => '${dt.day} ${_thaiMonth(dt.month)} ${dt.year}';
  String _thaiMonth(int m) => const [
        '',
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.'
      ][m];

  Widget _summaryBadge(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text('$label: ', style: TextStyle(color: color)),
            Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Icon _iconForType(ChangeType type) {
    return switch (type) {
      ChangeType.add => const Icon(Icons.add_circle_outline, color: Colors.green),
      ChangeType.update => const Icon(Icons.edit, color: Colors.blue),
      ChangeType.delete => const Icon(Icons.remove_circle_outline, color: Colors.grey),
      ChangeType.conflict => const Icon(Icons.error_outline, color: Colors.red),
    };
  }

  void _selectAll() => setState(() => selected.addAll(List.generate(items.length, (i) => i)));

  Future<bool> _confirmCounts(int adds, int updates, int deletes, {bool force = false}) async {
    final title = force ? 'Apply All (force) — ยืนยัน?' : 'ยืนยันการซิงก์';
    final content = 'ระบบจะดำเนินการ:\nเพิ่ม $adds รายการ\nแก้ไข $updates รายการ\nลบ $deletes รายการ\n\nดำเนินการต่อหรือไม่?';
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _confirmAndPerformSync(List<int> indices, {bool forceAll = false}) async {
    final adds = indices.where((i) => items[i].type == ChangeType.add).length;
    final updates = indices.where((i) => items[i].type == ChangeType.update).length;
    final deletes = indices.where((i) => items[i].type == ChangeType.delete).length;
    final ok = await _confirmCounts(adds, updates, deletes, force: forceAll);
    if (!ok) return;
    setState(() => loading = true);
    try {
      if (forceAll && widget.desiredCandidates == null) {
        await widget.controller.syncCalendar();
      } else {
        final candidates = [for (final i in indices) _candidateSource[i]];
        if (candidates.isEmpty) throw StateError('ไม่มีรายการสำหรับการซิงก์');
        await widget.controller.syncCandidates(candidates);
      }
      if (!mounted) return;
      final audit = widget.controller.auditEntries.isNotEmpty ? widget.controller.auditEntries.first : null;
      if (audit != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sync summary'),
            content: Text(audit.message),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed')));
      }
      selected.clear();
      if (widget.desiredCandidates != null) {
        await _loadCandidatePreview(widget.desiredCandidates!);
      } else {
        await _loadPreview();
      }
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ไม่สามารถซิงก์ได้'),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
        ),
      );
      setState(() => loading = false);
    }
  }

  void _showDiff(BuildContext context, ChangeItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (item.oldValue != null) ...[
              const Text('Old:'),
              Text(item.oldValue!),
              const SizedBox(height: 8),
            ],
            if (item.newValue != null) ...[
              const Text('New:'),
              Text(item.newValue!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
