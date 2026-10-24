import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripFixedSchedulePage extends StatefulWidget {
  const TripFixedSchedulePage({super.key});

  @override
  State<TripFixedSchedulePage> createState() => _TripFixedSchedulePageState();
}

class _TripFixedSchedulePageState extends State<TripFixedSchedulePage>
    with DraftAutosave<TripFixedSchedulePage> {
  TimeOfDay? selectedEndTime;
  static TimeOfDay? readTime(dynamic value) {
    final p = value?.toString().split(':');
    return p == null
        ? null
        : TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.fixedSchedules = fixedSchedules
        .map(
          (e) => <String, dynamic>{
            'name': e.place,
            'date': e.date == null ? null : TripDraft.date(e.date!),
            'startTime': '${TripDraft.time(e.time)}:00',
            'endTime': '${TripDraft.time(e.endTime)}:00',
          },
        )
        .toList();
    d.fixedScheduleInput = {
      'name': placeController.text,
      'date': selectedDate == null ? null : TripDraft.date(selectedDate!),
      'startTime': selectedTime == null ? null : TripDraft.time(selectedTime!),
      'endTime': selectedEndTime == null
          ? null
          : TripDraft.time(selectedEndTime!),
    };
  }

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    for (final e in d.fixedSchedules) {
      fixedSchedules.add(
        _FixedScheduleItem(
          date: DateTime.tryParse(e['date']?.toString() ?? ''),
          time: readTime(e['startTime'])!,
          endTime: readTime(e['endTime'])!,
          place: e['name'].toString(),
        ),
      );
    }
    final f = d.fixedScheduleInput;
    selectedDate = DateTime.tryParse(f['date']?.toString() ?? '');
    selectedTime = readTime(f['startTime']);
    selectedEndTime = readTime(f['endTime']);
    placeController.text = f['name']?.toString() ?? '';
  }

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final TextEditingController placeController = TextEditingController();

  final List<_FixedScheduleItem> fixedSchedules = [];

  @override
  void dispose() {
    placeController.dispose();
    super.dispose();
  }

  // =========================================================
  // 고정 일정 날짜 선택
  // =========================================================

  Future<void> _pickDate() async {
    final range = TripDraft.instance.period;
    if (range == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 여행 기간을 선택하세요.')));
      return;
    }
    if (TripDraft.instance.isUndated) {
      final picked = await showDialog<DateTime>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('여행 일차 선택'),
          children: [
            for (var day = 1; day <= TripDraft.instance.tripDays; day++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  TripDraft.instance.inputBase.add(Duration(days: day - 1)),
                ),
                child: Text('$day일차'),
              ),
          ],
        ),
      );
      if (picked != null && mounted) {
        setState(() => selectedDate = picked);
        saveDraft();
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      firstDate: range.start,
      lastDate: range.end,
      initialDate:
          selectedDate != null && TripDraft.instance.containsDate(selectedDate!)
          ? selectedDate!
          : range.start,
      helpText: '고정 일정 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedDate = picked;
    });
  }

  // =========================================================
  // 고정 일정 시간 선택
  // =========================================================

  Future<void> _pickTime({bool isEnd = false}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isEnd ? selectedEndTime : selectedTime) ??
          const TimeOfDay(hour: 10, minute: 0),
      helpText: '고정 일정 시간 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isEnd) {
        selectedEndTime = picked;
      } else {
        selectedTime = picked;
      }
    });
  }

  // =========================================================
  // 날짜 표시
  // yyyy-MM-dd(요일) 형식
  // =========================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 선택';
    }

    if (TripDraft.instance.isUndated)
      return '${date.difference(TripDraft.instance.inputBase).inDays + 1}일차';
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    final weekday = weekdays[date.weekday - 1];

    return '${DateFormat('yyyy-MM-dd').format(date)}($weekday)';
  }

  // =========================================================
  // 시간 선택 화면 표시
  // 오전 / 오후 12시간 형식
  // =========================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '시간 선택';
    }

    final isAm = time.hour < 12;

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    final minute = time.minute.toString().padLeft(2, '0');

    return '${isAm ? '오전' : '오후'} $hour:$minute';
  }

  // =========================================================
  // 등록된 일정의 시간 표시
  // 24시간 형식
  // =========================================================

  String _formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // =========================================================
  // 현재 입력 중인 고정 일정 전체 초기화
  //
  // 고정 일정 추가 카드 우측 상단의 X 버튼을 누르면
  // 날짜 / 시간 / 장소를 한 번에 지웁니다.
  // =========================================================

  void _clearCurrentInput() {
    FocusScope.of(context).unfocus();

    setState(() {
      selectedDate = null;
      selectedTime = null;
      selectedEndTime = null;
      placeController.clear();
    });
  }

  // =========================================================
  // 고정 일정 추가
  // =========================================================

  void _addFixedSchedule() {
    final place = placeController.text.trim();

    if (selectedDate == null ||
        selectedTime == null ||
        selectedEndTime == null ||
        place.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('날짜, 시간, 장소를 모두 입력해주세요.')));

      return;
    }

    if (selectedEndTime!.hour * 60 + selectedEndTime!.minute <=
        selectedTime!.hour * 60 + selectedTime!.minute) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다.')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      fixedSchedules.add(
        _FixedScheduleItem(
          date: selectedDate!,
          time: selectedTime!,
          endTime: selectedEndTime!,
          place: place,
        ),
      );

      // 날짜와 시간 순서대로 자동 정렬
      fixedSchedules.sort((a, b) {
        final dateCompare = (a.date ?? DateTime(9999)).compareTo(
          b.date ?? DateTime(9999),
        );

        if (dateCompare != 0) {
          return dateCompare;
        }

        final aMinutes = a.time.hour * 60 + a.time.minute;

        final bMinutes = b.time.hour * 60 + b.time.minute;

        return aMinutes.compareTo(bMinutes);
      });

      // 일정 추가 완료 후 날짜 / 시간 / 장소 초기화
      selectedDate = null;
      selectedTime = null;
      selectedEndTime = null;
      placeController.clear();
    });
  }

  // =========================================================
  // 이미 추가된 고정 일정 삭제
  // =========================================================

  void _removeFixedSchedule(_FixedScheduleItem item) {
    setState(() {
      fixedSchedules.remove(item);
    });
  }

  // =========================================================
  // 이전 / 다음 페이지 이동
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripAccommodation);
  }

  void _goNext() {
    if (fixedSchedules.any((e) => e.date == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('여행 기간이 바뀌었습니다. 날짜가 없는 고정 일정을 삭제하고 다시 추가하세요.'),
        ),
      );
      return;
    }
    if (placeController.text.isNotEmpty ||
        selectedDate != null ||
        selectedTime != null ||
        selectedEndTime != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('작성 중인 일정을 추가하거나 지워 주세요.')));
      return;
    }
    saveDraft();
    context.go(AppRoutes.tripCompanion);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  Widget build(BuildContext context) {
    // 날짜, 시간, 장소 중 하나라도 입력되어 있으면
    // 고정 일정 추가 카드 우측 상단에 X 버튼 표시
    final hasCurrentInput =
        selectedDate != null ||
        selectedTime != null ||
        selectedEndTime != null ||
        placeController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TripStepHeader(currentStep: 5),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 5),

                    const SizedBox(height: 34),

                    Text(
                      '꼭 넣어야 할\n일정이 있나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '예약한 식당, 공연, 투어처럼 반드시 고정해야 하는 일정을 입력해주세요.\nGoogle 지도에서 검색되지 않는 장소는 일정에서 제외되거나 일정 생성이 실패할 수 있습니다.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // =============================================
                          // 카드 제목 + 현재 입력값 전체 지우기
                          // =============================================

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '고정 일정 추가',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),

                              if (hasCurrentInput)
                                IconButton(
                                  tooltip: '입력 내용 지우기',
                                  onPressed: _clearCurrentInput,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textSecondary,
                                    size: 21,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // =============================================
                          // 날짜 / 시간 입력
                          // =============================================
                          _InputButton(
                            label: '날짜',
                            value: _formatDate(selectedDate),
                            icon: Icons.calendar_month_rounded,
                            selected: selectedDate != null,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _InputButton(
                                  label: '시작 시간',
                                  value: _formatTime(selectedTime),
                                  icon: Icons.schedule_rounded,
                                  selected: selectedTime != null,
                                  onTap: _pickTime,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Expanded(
                                child: _InputButton(
                                  label: '종료 시간',
                                  value: _formatTime(selectedEndTime),
                                  icon: Icons.schedule_rounded,
                                  selected: selectedEndTime != null,
                                  onTap: () => _pickTime(isEnd: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // =============================================
                          // 장소명 또는 주소 직접 입력
                          // =============================================

                          _PlaceTextField(
                            controller: placeController,

                            // 장소를 직접 입력하는 동안에도
                            // 우측 상단 X 버튼 표시 상태를 갱신
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _addFixedSchedule,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text(
                                '고정 일정 추가',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =================================================
                    // 추가된 고정 일정 목록
                    // =================================================
                    Row(
                      children: [
                        Text(
                          '추가된 고정 일정',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),

                        const Spacer(),

                        Text(
                          '${fixedSchedules.length}개',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (fixedSchedules.isEmpty)
                      const _EmptyFixedSchedule()
                    else
                      ...fixedSchedules.map(
                        (item) => _FixedScheduleCard(
                          item: item,
                          dateText: _formatDate(item.date),
                          timeText:
                              '${_formatTime24(item.time)} ~ ${_formatTime24(item.endTime)}',
                          onDelete: () {
                            _removeFixedSchedule(item);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            TripBottomNavigation(onPrevious: _goPrevious, onNext: _goNext),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 장소명 / 주소 직접 입력 필드
// ===========================================================

class _PlaceTextField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _PlaceTextField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.done,
        maxLength: 100,
        decoration: const InputDecoration(
          counterText: '',
          hintText: '장소명 또는 주소 입력',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.place_rounded, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      ),
    );
  }
}

// ===========================================================
// 날짜 / 시간 선택 버튼
// ===========================================================

class _InputButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _InputButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.primary.withValues(alpha: 0.05)
        : AppColors.background,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ===========================================================
// 추가된 고정 일정 카드
//
// 우측 X 버튼은 현재 입력값 초기화 버튼과 별개이며,
// 이미 등록한 해당 일정만 삭제합니다.
// ===========================================================

class _FixedScheduleCard extends StatelessWidget {
  final _FixedScheduleItem item;
  final String dateText;
  final String timeText;
  final VoidCallback onDelete;

  const _FixedScheduleCard({
    required this.item,
    required this.dateText,
    required this.timeText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.push_pin_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.place,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 6),

                Text(
                  '$dateText · $timeText',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: '일정 삭제',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 등록된 고정 일정이 없을 때 표시
// ===========================================================

class _EmptyFixedSchedule extends StatelessWidget {
  const _EmptyFixedSchedule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '고정 일정이 없습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 8),

          Text(
            '필수 일정이 없다면 바로 다음 단계로 넘어가도 됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 고정 일정 데이터 모델
// ===========================================================

class _FixedScheduleItem {
  final DateTime? date;
  final TimeOfDay time;
  final TimeOfDay endTime;
  final String place;

  _FixedScheduleItem({
    required this.date,
    required this.time,
    required this.endTime,
    required this.place,
  });
}
