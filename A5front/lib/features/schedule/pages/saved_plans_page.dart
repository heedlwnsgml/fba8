import '../../../core/widgets/app_dialog_actions.dart';
import '../../../core/widgets/three_second_hold.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/router/app_router.dart';

class SavedPlansPage extends StatelessWidget {
  const SavedPlansPage({super.key, this.initialSelection});
  final int? initialSelection;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('내 여행 일정'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(AppRoutes.home),
      ),
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: SavedPlansSection(initialSelection: initialSelection),
    ),
  );
}

class SavedPlansSection extends StatefulWidget {
  const SavedPlansSection({
    super.key,
    this.limit,
    this.api,
    this.initialSelection,
  });
  final PlannerApi? api;
  final int? limit;
  final int? initialSelection;
  @override
  State<SavedPlansSection> createState() => _SavedPlansSectionState();
}

class _SavedPlansSectionState extends State<SavedPlansSection> {
  late final PlannerApi api;
  int loadId = 0;
  bool _initialApplied = false;
  int? _loadedRevision;
  int? _loadedPlansRevision;
  void _onApiChanged() {
    if (_deleting) return;
    if (_loadedRevision != api.sessionRevision ||
        _loadedPlansRevision != api.plansRevision)
      _load();
  }

  List<Map<String, dynamic>>? _plans;
  String? _error;
  int? _opening;
  final Set<int> _selected = {};
  bool _selecting = false, _deleting = false;
  void _toggle(int id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });
  Future<void> _deleteSelected() async {
    if (_deleting || _selected.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_selected.length}개 일정 삭제'),
        content: const Text('선택한 여행 일정을 삭제하시겠습니까?'),
        actions: [
          AppDialogActions(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = true);
    final revision = api.sessionRevision;
    String? error;
    for (final id in _selected.toList()) {
      if (revision != api.sessionRevision) break;
      try {
        await api.deletePlan(id);
        _selected.remove(id);
      } catch (e) {
        error = e.toString();
      }
    }
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selecting = _selected.isNotEmpty;
    });
    await _load();
    if (mounted && error != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제하지 못한 일정이 있습니다. $error')));
  }

  @override
  void initState() {
    super.initState();
    api = widget.api ?? PlannerApi.instance;
    api.addListener(_onApiChanged);
    _load();
  }

  @override
  void dispose() {
    api.removeListener(_onApiChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++loadId, revision = api.sessionRevision;
    setState(() {
      if (_loadedRevision != revision) {
        _selected.clear();
        _selecting = false;
        _loadedRevision = revision;
        _plans = null;
      }
      _loadedPlansRevision = api.plansRevision;
      if (!api.isLoggedIn) _plans = [];
      _error = null;
    });
    if (!api.isLoggedIn) return;
    try {
      final plans = await api.listPlans();
      if (mounted && id == loadId && revision == api.sessionRevision)
        setState(() {
          _plans = plans;
          if (!_initialApplied &&
              widget.initialSelection != null &&
              plans.any((p) => p['id'] == widget.initialSelection)) {
            _selected.add(widget.initialSelection!);
            _selecting = true;
          }
          _initialApplied = true;
        });
    } catch (e) {
      if (mounted && id == loadId && revision == api.sessionRevision)
        setState(() => _error = e.toString());
    }
  }

  Future<void> _open(int id) async {
    if (_opening != null) return;
    setState(() => _opening = id);
    try {
      final data = await api.getPlan(id);
      if (mounted) context.go(AppRoutes.generated, extra: data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('목록 다시 불러오기')),
          if (!api.isLoggedIn)
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('로그인'),
            ),
        ],
      );
    if (_plans == null)
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    final plans = widget.limit == null
        ? _plans!
        : _plans!.take(widget.limit!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plans.isEmpty) const Text('저장된 여행 일정이 없습니다.'),
        if (plans.isNotEmpty && !_selecting)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selecting = true),
                  child: const Text('선택'),
                ),
              ],
            ),
          ),
        if (_selecting)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${_selected.length}개 선택'),
              TextButton(
                onPressed: _deleting
                    ? null
                    : () => setState(() {
                        final ids = plans
                            .map((p) => (p['id'] as num).toInt())
                            .toSet();
                        if (ids.every(_selected.contains)) {
                          _selected.removeAll(ids);
                        } else {
                          _selected.addAll(ids);
                        }
                      }),
                child: Text(
                  plans.every(
                        (p) => _selected.contains((p['id'] as num).toInt()),
                      )
                      ? '전체 해제'
                      : '전체 선택',
                ),
              ),
              TextButton(
                onPressed: _deleting
                    ? null
                    : () => setState(() {
                        _selected.clear();
                        _selecting = false;
                      }),
                child: const Text('취소'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _deleting || _selected.isEmpty
                    ? null
                    : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text(_deleting ? '삭제 중' : '선택 삭제'),
              ),
            ],
          ),
        for (final plan in plans)
          _HeldPlanCard(
            key: ValueKey(plan['id']),
            selecting: _selecting,
            selected: _selected.contains((plan['id'] as num).toInt()),
            enabled: !_deleting && _opening == null,
            onHeld: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selecting = true;
                _selected.add((plan['id'] as num).toInt());
              });
            },
            onTap: () => _selecting
                ? _toggle((plan['id'] as num).toInt())
                : _open((plan['id'] as num).toInt()),
            title: '${plan['title']}',
            subtitle: plan['startDate'] == null
                ? '${(plan['tripDays'] as num?)?.toInt() ?? 1}일 · 날짜 미정'
                : '${plan['startDate']} ~ ${plan['endDate']}',
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _load, child: const Text('새로고침')),
        ),
      ],
    );
  }
}

class _HeldPlanCard extends StatefulWidget {
  const _HeldPlanCard({
    super.key,
    required this.selecting,
    required this.selected,
    required this.enabled,
    required this.onHeld,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });
  final bool selecting, selected, enabled;
  final VoidCallback onHeld, onTap;
  final String title, subtitle;
  @override
  State<_HeldPlanCard> createState() => _HeldPlanCardState();
}

class _HeldPlanCardState extends State<_HeldPlanCard> {
  @override
  Widget build(BuildContext context) => ThreeSecondHold(
    onHeld: widget.enabled && !widget.selecting ? widget.onHeld : null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: Card(
        child: ListTile(
          leading: widget.selecting
              ? Checkbox(
                  value: widget.selected,
                  onChanged: widget.enabled ? (_) => widget.onTap() : null,
                )
              : null,
          title: Text(widget.title),
          subtitle: Text(widget.subtitle),
          trailing: widget.selecting ? null : const Icon(Icons.chevron_right),
        ),
      ),
    ),
  );
}
