import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripScheduleSettingsPage extends StatefulWidget {
  const TripScheduleSettingsPage({super.key});

  @override
  State<TripScheduleSettingsPage> createState() =>
      _TripScheduleSettingsPageState();
}

class _TripScheduleSettingsPageState extends State<TripScheduleSettingsPage>
    with DraftAutosave<TripScheduleSettingsPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.pace = selectedPace;
    d.dailyStart = startTime;
    d.dailyEnd = endTime;
    d.mealsPerDay = mealsPerDay;
    d.includeSnacks = includeSnacks;
  }

  // =========================================================
  // 일정 설정 기본값
  //
  // 일정 강도 : 평균
  // 시작 시간 : 오전 9:00
  // 종료 시간 : 오후 10:00 (22:00)
  // =========================================================

  String selectedPace = '평범한';
  int mealsPerDay = 2;
  bool includeSnacks = false;

  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);

  TimeOfDay endTime = const TimeOfDay(hour: 22, minute: 0);

  // =========================================================
  // 일정 강도 선택 항목
  // =========================================================

  final List<_SchedulePaceItem> paceItems = const [
    _SchedulePaceItem(
      name: '여유로운',
      description: '이동과 휴식에 여유를 두고 적은 장소를 방문합니다.',
      icon: Icons.spa_rounded,
    ),
    _SchedulePaceItem(
      name: '평범한',
      description: '관광, 이동, 휴식의 균형을 맞춰 일정을 구성합니다.',
      icon: Icons.balance_rounded,
    ),
    _SchedulePaceItem(
      name: '알찬',
      description: '하루에 더 많은 장소를 방문할 수 있도록 구성합니다.',
      icon: Icons.bolt_rounded,
    ),
  ];

  // =========================================================
  // 일정 강도 선택
  // =========================================================

  void _selectPace(String pace) {
    setState(() {
      selectedPace = pace;
    });
  }

  // =========================================================
  // 하루 일정 시작 시간 선택
  // =========================================================

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: '일정 시작 시간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      startTime = selected;
    });
  }

  // =========================================================
  // 하루 일정 종료 시간 선택
  // =========================================================

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: '일정 종료 시간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      endTime = selected;
    });
  }

  // =========================================================
  // 시간 비교
  //
  // TimeOfDay를 분 단위로 변환해
  // 시작 시간과 종료 시간을 비교합니다.
  // =========================================================

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  bool get _isValidTimeRange {
    return _timeToMinutes(endTime) > _timeToMinutes(startTime);
  }

  // =========================================================
  // 시간 표시
  //
  // 화면에서는 오전 / 오후 12시간 형식으로 표시합니다.
  //
  // 09:00 → 오전 9:00
  // 22:00 → 오후 10:00
  // =========================================================

  String _formatTime(TimeOfDay time) {
    final isAm = time.hour < 12;

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    final minute = time.minute.toString().padLeft(2, '0');

    return '${isAm ? '오전' : '오후'} $hour:$minute';
  }

  // =========================================================
  // 이전 단계
  //
  // 9단계 일정 설정 → 8단계 이동수단
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripTransport);
  }

  // =========================================================
  // AI 일정 생성
  //
  // 종료 시간이 시작 시간보다 늦은지 확인한 뒤
  // 로딩 화면으로 이동합니다.
  // =========================================================

  Future<void> _generateSchedule() async {
    if (!_isValidTimeRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 종료 시간은 시작 시간보다 늦어야 합니다.')),
      );

      return;
    }

    saveDraft();
    context.go(AppRoutes.loading);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    selectedPace = d.pace == '빡센'
        ? '알찬'
        : d.pace == '평균'
        ? '평범한'
        : d.pace;
    startTime = d.dailyStart;
    endTime = d.dailyEnd;
    mealsPerDay = d.mealsPerDay.clamp(1, d.maxMealsPerDay).toInt();
    d.mealsPerDay = mealsPerDay;
    includeSnacks = d.includeSnacks || d.themes.contains('카페');
    d.includeSnacks = includeSnacks;
  }

  Widget _mealSettings() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                '하루 식사 횟수',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '한 가지를 선택해주세요. 짧은 입출국 날은 가능한 식사만 배치합니다.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (
                var count = 1;
                count <= TripDraft.instance.maxMealsPerDay;
                count++
              )
                SizedBox(
                  width: 96,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('$count회'),
                    value: mealsPerDay == count,
                    onChanged: (_) => setState(() => mealsPerDay = count),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('중간에 카페·간식도 들르기'),
            subtitle: const Text('식사 횟수와 별도로 하루 최대 2곳을 추천합니다.'),
            value: includeSnacks,
            onChanged: (value) =>
                setState(() => includeSnacks = value ?? false),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 9단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 9),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 9),

                    const SizedBox(height: 34),

                    Text(
                      '마지막으로\n일정을 설정해주세요.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '관광지별 여유시간과 하루 일정의 시작·종료 시간을 설정해주세요.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // =================================================
                    // 관광지별 여유시간
                    // =================================================
                    Text(
                      '관광지별 여유시간',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '선택지에 따라서 여행 장소의 체류 및 여유시간이 조정되어 하루의 여행지 개수가 제한될 수 있습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 16),

                    ...paceItems.map((pace) {
                      final selected = selectedPace == pace.name;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SchedulePaceCard(
                          item: pace,
                          selected: selected,
                          onTap: () {
                            _selectPace(pace.name);
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 22),

                    // =================================================
                    // 하루 일정 시간
                    // =================================================
                    _mealSettings(),
                    const SizedBox(height: 28),
                    Text(
                      '하루 일정 시간',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '숙소에서 출발하고 돌아올 시간을 설정해주세요. 왕복 이동시간도 일정에 포함됩니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // 시작 시간
                    // =================================================
                    _ScheduleTimeCard(
                      title: '일정 시작 시간 · 숙소 출발',
                      description: '숙소에서 나오는 시간입니다. 첫 장소까지의 이동시간을 포함합니다.',
                      timeText: _formatTime(startTime),
                      icon: Icons.wb_sunny_rounded,
                      onTap: _selectStartTime,
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // 종료 시간
                    // =================================================
                    _ScheduleTimeCard(
                      title: '일정 종료 시간 · 숙소 도착',
                      description: '숙소에 도착할 목표 시간입니다. 마지막 장소에서 돌아오는 시간을 포함합니다.',
                      timeText: _formatTime(endTime),
                      icon: Icons.nights_stay_rounded,
                      onTap: _selectEndTime,
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // 현재 설정 요약
                    // =================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.primary,
                                size: 21,
                              ),

                              SizedBox(width: 8),

                              Text(
                                '일정 설정',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          _SummaryRow(label: '관광지별 여유시간', value: selectedPace),

                          const SizedBox(height: 8),

                          _SummaryRow(
                            label: '시작 시간',
                            value: _formatTime(startTime),
                          ),

                          const SizedBox(height: 8),

                          _SummaryRow(
                            label: '종료 시간',
                            value: _formatTime(endTime),
                          ),
                        ],
                      ),
                    ),

                    // 잘못된 시간 범위인 경우 즉시 안내
                    if (!_isValidTimeRange) ...[
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 21,
                            ),

                            SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                '일정 종료 시간은 시작 시간보다 늦게 설정해주세요.',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // =================================================
            // 이전 → 이동수단
            // AI 일정 생성하기 → 로딩
            // =================================================
            TripBottomNavigation(
              onPrevious: _goPrevious,
              onNext: _generateSchedule,
              nextText: 'AI 일정 생성하기',
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 일정 강도 선택 카드
// ===========================================================

class _SchedulePaceCard extends StatelessWidget {
  final _SchedulePaceItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SchedulePaceCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: color, size: 27),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 시작 / 종료 시간 선택 카드
// ===========================================================

class _ScheduleTimeCard extends StatelessWidget {
  final String title;
  final String description;
  final String timeText;
  final IconData icon;
  final VoidCallback onTap;

  const _ScheduleTimeCard({
    required this.title,
    required this.description,
    required this.timeText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 27),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 현재 설정 요약 행
// ===========================================================

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// 일정 강도 데이터 모델
// ===========================================================

class _SchedulePaceItem {
  final String name;
  final String description;
  final IconData icon;

  const _SchedulePaceItem({
    required this.name,
    required this.description,
    required this.icon,
  });
}
