import 'dart:async';
import 'app_dialog_actions.dart';
import 'package:flutter/material.dart';
import '../network/planner_api.dart';
import '../router/app_router.dart';

class GenerationNotifications extends StatefulWidget {
  const GenerationNotifications({super.key, required this.child, this.api});
  final Widget child;
  final PlannerApi? api;
  @override
  State<GenerationNotifications> createState() =>
      _GenerationNotificationsState();
}

class _GenerationNotificationsState extends State<GenerationNotifications>
    with WidgetsBindingObserver {
  PlannerApi get api => widget.api ?? PlannerApi.instance;
  final _notified = <String>{};
  final _hidden = <String>{};
  final _expiry = <Timer>[];
  bool _showing = false, _resumed = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    api.addListener(_changed);
  }

  @override
  void dispose() {
    for (final timer in _expiry) {
      timer.cancel();
    }
    api.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _changed();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  Future<void> _announce() async {
    if (!mounted || _showing || !_resumed) return;
    final ready = api.generationTasks.where(
      (t) =>
          (t.status == 'SUCCEEDED' || t.status == 'FAILED') &&
          !_notified.contains(t.id),
    );
    if (ready.isEmpty) return;
    final context = generationNavigatorKey.currentContext;
    if (context == null) return;
    final task = ready.first;
    _showing = true;
    _notified.add(task.id);
    final revision = api.sessionRevision;
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          task.status == 'SUCCEEDED'
              ? (task.request['researchPlanId'] != null
                    ? '교통비 계산 완료'
                    : '일정 생성 완료')
              : '작업 실패',
        ),
        content: Text(
          task.status == 'SUCCEEDED'
              ? (task.request['researchPlanId'] != null
                    ? '${task.title} 거리 평균 교통비 계산이 끝났습니다.\n${(task.result?['response'] as Map?)?['transportResearch']?['message'] ?? '확인된 구간은 반영하고 미확인 구간은 유지했습니다.'}'
                    : '${task.title} 일정이 완성되어 저장되었습니다.')
              : task.error ?? '생성 중 오류가 발생했습니다.',
        ),
        actions: [
          AppDialogActions(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('닫기'),
              ),
              if (task.result != null)
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('일정 보기'),
                ),
            ],
          ),
        ],
      ),
    );
    _showing = false;
    _expiry.add(
      Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _hidden.add(task.id));
      }),
    );
    if (open == true && revision == api.sessionRevision)
      appRouter.go(AppRoutes.generated, extra: task.result);
    _changed();
  }

  Future<void> _jobs() async {
    final context = generationNavigatorKey.currentContext;
    if (context == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .65,
          child: ListenableBuilder(
            listenable: api,
            builder: (c, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '일정 생성 작업',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (final task in api.generationTasks.reversed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            task.active
                                ? task.message
                                : task.status == 'SUCCEEDED'
                                ? '완료 · 자동 저장됨'
                                : task.status == 'CANCELLED'
                                ? '취소됨'
                                : task.error ?? '실패',
                          ),
                          if (task.active && task.status != 'CANCELLING')
                            TextButton(
                              onPressed: () async {
                                try {
                                  await api.cancelGeneration(task.id);
                                } catch (e) {
                                  if (c.mounted)
                                    ScaffoldMessenger.of(c).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                }
                              },
                              child: const Text('생성 취소'),
                            ),
                          if (task.result != null)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(c);
                                appRouter.go(
                                  AppRoutes.generated,
                                  extra: task.result,
                                );
                              },
                              child: const Text('일정 보기'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = api.generationTasks
        .where((t) => t.active || !_hidden.contains(t.id))
        .toList();
    final active = jobs.where((t) => t.active).length;
    return Stack(
      children: [
        widget.child,
        if (jobs.isNotEmpty)
          Positioned(
            right: 12,
            width: 160,
            top: MediaQuery.paddingOf(context).top + 64,
            child: FilledButton.tonalIcon(
              // This floating control must not inherit the full-width form-button minimum.
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _jobs,
              icon: Icon(
                active > 0 ? Icons.hourglass_top : Icons.task_alt,
                size: 18,
              ),
              label: Text(active > 0 ? '생성 중 $active/2' : '생성 결과'),
            ),
          ),
      ],
    );
  }
}
