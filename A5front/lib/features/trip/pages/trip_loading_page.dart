import '../../../core/widgets/app_dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';

class TripLoadingPage extends StatefulWidget {
  const TripLoadingPage({super.key, this.api});
  final PlannerApi? api;
  @override
  State<TripLoadingPage> createState() => _TripLoadingPageState();
}

class _TripLoadingPageState extends State<TripLoadingPage> {
  PlannerApi get api => widget.api ?? PlannerApi.instance;
  GenerationTask? _task;
  String? _error;
  bool _checking = true, _cancelling = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final request = TripDraft.instance.toRequest();
      final validation = await api.validatePlan(request);
      if (!mounted) return;
      if (validation['isWarning'] == true) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('일정 검토'),
            content: Text('${validation['warningMessage']}'),
            actions: [
              AppDialogActions(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('조건 수정'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('계속 생성'),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (proceed != true) {
          context.go(AppRoutes.tripPeriod);
          return;
        }
      }
      final task = api.startGeneration(request);
      TripDraft.instance.resetInputs();
      _task = task;
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted)
        setState(() {
          _checking = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await api.cancelGeneration(_task!.id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) context.go(AppRoutes.home);
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('일정 생성'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ListenableBuilder(
            listenable: api,
            builder: (context, _) => Column(
              children: [
                if (_checking || _task?.active == true)
                  const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _error ??
                      (_checking
                          ? '여행 조건을 검증하고 있습니다.'
                          : _task?.status == 'FAILED'
                          ? (_task?.error ?? '생성에 실패했습니다.')
                          : _task?.status == 'SUCCEEDED'
                          ? '일정이 완성되었습니다.'
                          : _task?.message ?? ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_task?.active == true) ...[
                  const Text(
                    '서버에서 생성 중입니다. 다른 화면을 이용해도 계속되며, 앱에서 완료 팝업으로 알려드립니다. 최대 2개까지 동시에 요청할 수 있습니다.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _cancelling || _task?.status == 'CANCELLING'
                          ? null
                          : _cancel,
                      child: Text(
                        _cancelling || _task?.status == 'CANCELLING'
                            ? '취소 처리 중…'
                            : '생성 취소',
                      ),
                    ),
                  ),
                ],
                if (_task?.result != null)
                  FilledButton(
                    onPressed: () =>
                        context.go(AppRoutes.generated, extra: _task!.result),
                    child: const Text('완성된 일정 보기'),
                  ),
                if (_error != null)
                  TextButton(
                    onPressed: () => context.go(AppRoutes.tripScheduleSettings),
                    child: const Text('조건 수정'),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('홈으로 이동'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
