import '../../../core/widgets/three_second_hold.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:go_router/go_router.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/state/itinerary_presentation.dart';
import '../../../core/theme/app_colors.dart';

class LatestTripPreview extends StatefulWidget {
  const LatestTripPreview({super.key, this.api});
  final PlannerApi? api;
  @override
  State<LatestTripPreview> createState() => _LatestTripPreviewState();
}

class _LatestTripPreviewState extends State<LatestTripPreview> {
  late final PlannerApi api;
  final PageController pages = PageController();
  Map<String, dynamic>? summary, detail;
  bool loading = true;
  String? error;
  int day = 0, loadId = 0;
  int _session = -1, _plans = -1;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? PlannerApi.instance;
    api.addListener(_apiChanged);
    _apiChanged();
  }

  @override
  void dispose() {
    api.removeListener(_apiChanged);
    pages.dispose();
    super.dispose();
  }

  void _apiChanged() {
    if (_session == api.sessionRevision && _plans == api.plansRevision) return;
    final accountChanged = _session != api.sessionRevision;
    _session = api.sessionRevision;
    _plans = api.plansRevision;
    if (accountChanged) {
      summary = null;
      detail = null;
    }
    _load();
  }

  Future<void> _load() async {
    final id = ++loadId, revision = api.sessionRevision;
    setState(() {
      loading = api.isLoggedIn && detail == null;
      if (!api.isLoggedIn) {
        summary = null;
        detail = null;
      }
      error = null;
      day = 0;
    });
    if (!api.isLoggedIn) return;
    try {
      final plans = await api.listPlans();
      plans.sort((a, b) => (b['id'] as num).compareTo(a['id'] as num));
      final latest = plans.isEmpty ? null : plans.first;
      final data = latest == null
          ? null
          : await api.getPlan((latest['id'] as num).toInt());
      if (!mounted || id != loadId || revision != api.sessionRevision) return;
      setState(() {
        summary = latest;
        detail = data;
        loading = false;
      });
      if (pages.hasClients) pages.jumpToPage(0);
    } catch (e) {
      if (mounted && id == loadId && revision == api.sessionRevision)
        setState(() {
          loading = false;
          error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      );
    if (error != null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!),
          TextButton(onPressed: _load, child: const Text('다시 불러오기')),
        ],
      );
    if (detail == null)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          '일정이 없습니다.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    final request = Map<String, dynamic>.from(detail!['request'] as Map),
        response = detail!['response'] as Map;
    final timeline = (response['timeline'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final start =
            DateTime.tryParse(request['startDate']?.toString() ?? '') ??
            DateTime(1970),
        end =
            DateTime.tryParse(request['endDate']?.toString() ?? '') ??
            DateTime(
              1970,
            ).add(Duration(days: (request['tripDays'] as num).toInt() - 1));
    final count = end.difference(start).inDays + 1;
    return ThreeSecondHold(
      onHeld: () {
        HapticFeedback.selectionClick();
        context.go(AppRoutes.schedule, extra: (summary!['id'] as num).toInt());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary!['title']}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          request['startDate'] == null
                              ? '날짜 미정'
                              : '${request['startDate']} ~ ${request['endDate']}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '일정 상세보기',
                    onPressed: () =>
                        context.go(AppRoutes.generated, extra: detail),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 일차',
                  onPressed: day > 0
                      ? () => pages.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        )
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    request['startDate'] == null
                        ? '${day + 1}일차 · 날짜 미정'
                        : '${day + 1}일차 · ${TripDate.format(start.add(Duration(days: day)))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '다음 일차',
                  onPressed: day < count - 1
                      ? () => pages.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            SizedBox(
              height: 300,
              child: PageView.builder(
                scrollBehavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                controller: pages,
                itemCount: count,
                onPageChanged: (value) => setState(() => day = value),
                itemBuilder: (context, index) {
                  final items =
                      timeline.where((i) => i['day'] == index + 1).toList()
                        ..sort(
                          (a, b) =>
                              itineraryOrder(a).compareTo(itineraryOrder(b)),
                        );
                  if (items.isEmpty)
                    return const Center(child: Text('이 날의 일정이 없습니다.'));
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final leg = item['transportFromPrevious'];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${item['time']}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['placeName']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  itineraryCategory(item),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (leg is Map &&
                                    leg['durationMinutes'] is num &&
                                    (leg['durationMinutes'] as num) >= 0)
                                  Text(
                                    itineraryTransportSummary(leg),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '좌우로 밀어 다른 일차를 확인하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripDate {
  static String format(DateTime date) => '${date.month}월 ${date.day}일';
}
