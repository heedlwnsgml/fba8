import 'package:flutter/material.dart';
import '../network/planner_api.dart';
import 'app_dialog_actions.dart';

class EndTimeApprovalDialog extends StatefulWidget {
  const EndTimeApprovalDialog({
    super.key,
    required this.api,
    required this.task,
    required this.approval,
  });
  final PlannerApi api;
  final GenerationTask task;
  final Map<String, dynamic> approval;
  @override
  State<EndTimeApprovalDialog> createState() => _EndTimeApprovalDialogState();
}

class _EndTimeApprovalDialogState extends State<EndTimeApprovalDialog> {
  bool busy = false;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    widget.api.addListener(jobChanged);
  }

  @override
  void dispose() {
    widget.api.removeListener(jobChanged);
    super.dispose();
  }

  void close() {
    if (closing || !mounted) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void jobChanged() {
    final current = widget.task.endTimeApproval;
    if (widget.api.sessionRevision != widget.task.revision ||
        !widget.task.active ||
        widget.task.status != 'WAITING_APPROVAL' ||
        current == null ||
        current['decisionId'] != widget.approval['decisionId'])
      close();
  }

  String? error;
  Future<void> decide(bool allow) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.decideGenerationEndTime(
        widget.task.id,
        widget.approval['decisionId'].toString(),
        allow,
      );
      if (mounted) close();
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.approval;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('${a['day']}일차 종료 시간 확인')),
          IconButton(
            tooltip: '나중에 선택',
            onPressed: busy ? null : close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a['date'] != null)
              Text(
                a['date'].toString(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('설정한 종료 시각  ${a['plannedEndTime']}'),
                  const SizedBox(height: 8),
                  Text(
                    '예상 종료 시각  ${a['expectedEndTime']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${a['overtimeMinutes']}분 초과'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('허용하면 ${a['day']}일차만 설정한 종료 시각을 넘겨 일정을 만듭니다.'),
            const SizedBox(height: 10),
            const Text(
              '거부하면 종료 시각을 넘기지 않는 대안을 찾습니다. 가능한 대안이 없으면 일정 생성이 실패할 수 있습니다.',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppDialogActions(
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => decide(false),
              child: const Text('거부'),
            ),
            FilledButton(
              onPressed: busy ? null : () => decide(true),
              child: Text(busy ? '반영 중…' : '허용'),
            ),
          ],
        ),
      ],
    );
  }
}
