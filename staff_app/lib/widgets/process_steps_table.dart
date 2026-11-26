import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';

class ProcessStepsTable extends StatelessWidget {
  final List<dynamic> steps;
  final bool editable;
  final int? busySno;
  final Future<void> Function(int sNo, {String? planningDate, String? actualDate})? onUpdateStep;

  const ProcessStepsTable({
    super.key,
    required this.steps,
    this.editable = false,
    this.busySno,
    this.onUpdateStep,
  });

  String _todayShort() => DateFormat('dd.MM.yy').format(DateTime.now());

  Future<void> _editDateCell(
    BuildContext context, {
    required Map<String, dynamic> row,
    required bool isActual,
  }) async {
    if (!editable || onUpdateStep == null) return;
    final sNo = int.tryParse('${row['s_no']}') ?? 0;
    if (sNo < 6) return;

    final currentVal = ((isActual ? row['actual_date'] : row['planning_date']) ?? '').toString().trim();
    final ctrl = TextEditingController(text: currentVal);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '$sNo. ${row['process_name']}',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isActual ? 'Set Actual Date / Completed Status' : 'Set Planning Date',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.woodPrimary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: isActual ? 'Actual Date (e.g. ${_todayShort()})' : 'Planning Date (e.g. ${_todayShort()})',
                prefixIcon: const Icon(Icons.event_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  onPressed: () => Navigator.pop(ctx, _todayShort()),
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: Text('Today (${_todayShort()})'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null && ctx.mounted) {
                      Navigator.pop(ctx, DateFormat('dd.MM.yy').format(picked));
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('Pick Calendar'),
                ),
                if (!isActual)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, '-'),
                    child: const Text('Mark "-" (Skip)'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Clear', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (isActual) {
      await onUpdateStep!(sNo, actualDate: result);
    } else {
      await onUpdateStep!(sNo, planningDate: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = steps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (parsed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Process list not initialized yet.')),
      );
    }

    final trackable = parsed.where((r) => (int.tryParse('${r['s_no']}') ?? 0) >= 6).toList();
    final doneCount = trackable.where((r) {
      final a = (r['actual_date'] ?? '').toString().trim();
      return a.isNotEmpty && a != '-';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$doneCount / ${trackable.length} Processes Done',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.success),
                ),
              ),
              if (editable) ...[
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Rows 1–5 auto-filled • Tap Planning / Actual cells on rows 6–36 to set status',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Table Header matching sheet columns
              Container(
                color: AppTheme.woodDark,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text('S.No',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 5,
                      child: Text('Process',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: Text('Planning Date',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.brass, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: Text('Actual Date',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.brass, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              ...parsed.map((row) {
                final sNo = int.tryParse('${row['s_no']}') ?? 0;
                final isHeaderRow = sNo <= 5 || row['is_readonly'] == 1;
                final plan = (row['planning_date'] ?? '').toString().trim();
                final actual = (row['actual_date'] ?? '').toString().trim();
                final isDone = !isHeaderRow && actual.isNotEmpty && actual != '-';
                final isBusy = busySno == sNo;

                final bgColor = isHeaderRow
                    ? const Color(0xFFF6EFE6)
                    : (isDone ? const Color(0xFFEAF7EF) : Colors.white);

                return Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: const Border(top: BorderSide(color: Color(0xFFD9D0C5), width: 0.8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '$sNo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isHeaderRow ? FontWeight.w800 : FontWeight.w700,
                            color: isHeaderRow ? AppTheme.woodDark : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${row['process_name'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isHeaderRow || isDone ? FontWeight.w700 : FontWeight.w500,
                                  color: isHeaderRow ? AppTheme.woodDark : AppTheme.textDark,
                                ),
                              ),
                            ),
                            if (isDone)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: isHeaderRow
                            ? const SizedBox.shrink()
                            : InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: editable && !isBusy
                                    ? () => _editDateCell(context, row: row, isActual: false)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: editable ? AppTheme.bg : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: editable
                                        ? Border.all(color: plan.isNotEmpty ? AppTheme.woodPrimary : Colors.black12)
                                        : null,
                                  ),
                                  child: Text(
                                    plan.isNotEmpty ? plan : (editable ? 'Set' : '-'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: plan.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                                      color: plan.isNotEmpty ? AppTheme.woodDark : Colors.black38,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: isHeaderRow
                            ? const SizedBox.shrink()
                            : isBusy
                                ? const Center(
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: editable
                                        ? () => _editDateCell(context, row: row, isActual: true)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? AppTheme.success.withValues(alpha: 0.14)
                                            : (editable ? const Color(0xFFFFF8EE) : Colors.transparent),
                                        borderRadius: BorderRadius.circular(6),
                                        border: editable
                                            ? Border.all(
                                                color: isDone ? AppTheme.success : AppTheme.brass.withValues(alpha: 0.6),
                                              )
                                            : null,
                                      ),
                                      child: Text(
                                        actual.isNotEmpty ? actual : (editable ? 'Done' : '-'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                                          color: isDone ? AppTheme.success : (editable ? AppTheme.woodPrimary : Colors.black38),
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
