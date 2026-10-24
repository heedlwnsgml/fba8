import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/lodging_budget_fields.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripAccommodationPage extends StatefulWidget {
  /// 추후 Riverpod으로 여행 기간과 연결하기 전까지
  /// 외부에서 날짜 범위를 넘길 수 있도록 유지합니다.
  final DateTimeRange? travelPeriod;

  const TripAccommodationPage({super.key, this.travelPeriod});

  @override
  State<TripAccommodationPage> createState() => _TripAccommodationPageState();
}

class _TripAccommodationPageState extends State<TripAccommodationPage>
    with DraftAutosave<TripAccommodationPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.suggestHotel = true;
    d.accommodations = _accommodations
        .map(
          (e) => <String, dynamic>{
            'name': e.place,
            'address': e.place,
            'checkIn': e.startDate == null
                ? null
                : TripDraft.date(e.startDate!),
            'checkOut': e.endDate == null ? null : TripDraft.date(e.endDate!),
          },
        )
        .toList();
  }

  // =========================================================
  // 등록된 숙소 목록
  //
  // 숙소는 선택 사항이며 여러 개 등록할 수 있습니다.
  // =========================================================

  final List<_AccommodationEntry> _accommodations = [];

  late final DateTime _defaultFirstDate;
  late final DateTime _defaultLastDate;

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    d.suggestHotel = true;
    for (final a in d.accommodations) {
      final e = _AccommodationEntry();
      e.place = a['name']?.toString() ?? '';
      e.startDate = DateTime.tryParse(a['checkIn']?.toString() ?? '');
      e.endDate = DateTime.tryParse(a['checkOut']?.toString() ?? '');
      _accommodations.add(e);
    }

    // 여행 기간 정보가 아직 연결되지 않은 경우를 대비해
    // 오늘부터 최대 2년 뒤까지 선택할 수 있도록 기본 범위를 설정합니다.
    _defaultFirstDate = DateUtils.dateOnly(DateTime.now());

    _defaultLastDate = DateTime(
      _defaultFirstDate.year + 2,
      _defaultFirstDate.month,
      _defaultFirstDate.day,
    );
  }

  // =========================================================
  // 숙박 시작일 / 종료일 선택
  //
  // 종료일은 시작일보다 앞설 수 없고,
  // 시작일 역시 선택된 종료일보다 뒤로 갈 수 없습니다.
  // =========================================================

  Future<void> _pickDate(
    _AccommodationEntry entry, {
    required bool isStart,
  }) async {
    if (widget.travelPeriod == null && TripDraft.instance.period == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 여행 기간을 선택하세요.')));
      return;
    }
    final firstDate = DateUtils.dateOnly(
      (widget.travelPeriod ?? TripDraft.instance.period)?.start ??
          _defaultFirstDate,
    );

    final lastDate = DateUtils.dateOnly(
      (widget.travelPeriod ?? TripDraft.instance.period)?.end ??
          _defaultLastDate,
    );

    // 시작일 선택 시:
    // 여행 시작일 ~ 현재 선택된 종료일
    //
    // 종료일 선택 시:
    // 현재 선택된 시작일 ~ 여행 종료일
    final lowerBound = isStart ? firstDate : entry.startDate ?? firstDate;

    final upperBound = isStart ? entry.endDate ?? lastDate : lastDate;

    final initialDate =
        (isStart ? entry.startDate : entry.endDate) ?? lowerBound;

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
        setState(() {
          if (isStart)
            entry.startDate = picked;
          else
            entry.endDate = picked;
        });
        saveDraft();
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      firstDate: lowerBound,
      lastDate: upperBound,
      initialDate: initialDate,
      helpText: isStart ? '숙소 시작일 선택' : '숙소 종료일 선택',
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

    if (!mounted || picked == null || !_accommodations.contains(entry)) {
      return;
    }

    setState(() {
      if (isStart) {
        entry.startDate = picked;
      } else {
        entry.endDate = picked;
      }
    });
  }

  // =========================================================
  // 숙소 추가
  //
  // 새 숙소 카드를 목록 마지막에 추가합니다.
  // =========================================================

  void _addAccommodation() {
    setState(() {
      _accommodations.add(_AccommodationEntry());
    });
  }

  // =========================================================
  // 숙소 삭제
  //
  // 삭제 후 화면 번호는 현재 List 순서에 따라
  // 자동으로 다시 1, 2, 3... 형태로 표시됩니다.
  // =========================================================

  void _removeAccommodation(_AccommodationEntry entry) {
    setState(() {
      _accommodations.remove(entry);
    });
  }

  // =========================================================
  // 숙소명 / 주소 입력
  //
  // Google Places 검색은 사용하지 않고
  // 사용자가 직접 입력한 문자열만 저장합니다.
  // =========================================================

  void _updatePlace(_AccommodationEntry entry, String value) {
    entry.place = value;
    saveDraft();
  }

  // =========================================================
  // 페이지 이동
  //
  // 변경된 흐름:
  //
  // 3단계 입출국 정보
  //      ↓
  // 4단계 숙소
  //      ↓
  // 5단계 고정 일정
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripEntryExit);
  }

  void _goNext() {
    if (_accommodations.any(
      (e) => e.place.trim().isEmpty || e.startDate == null || e.endDate == null,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('숙소 이름과 날짜를 입력하세요.')));
      return;
    }
    saveDraft();
    context.go(AppRoutes.tripFixedSchedule);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 4단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 4),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 4),

                    const SizedBox(height: 34),

                    Text(
                      '어디에서\n머무르시나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '시작 시간은 숙소 출발, 종료 시간은 숙소 도착 시각입니다. 숙소를 지정하지 않은 날은 자동으로 추천합니다.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 16),
                    // 등록된 숙소가 없는 경우
                    // =================================================

                    if (_accommodations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          '아직 등록한 숙소가 없습니다.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),

                    // =================================================
                    // 등록된 숙소 카드
                    // =================================================
                    const LodgingBudgetFields(),
                    const SizedBox(height: 16),
                    for (var index = 0; index < _accommodations.length; index++)
                      _AccommodationCard(
                        key: ObjectKey(_accommodations[index]),
                        number: index + 1,
                        entry: _accommodations[index],
                        onStartDate: () {
                          _pickDate(_accommodations[index], isStart: true);
                        },
                        onEndDate: () {
                          _pickDate(_accommodations[index], isStart: false);
                        },
                        onPlaceChanged: (value) {
                          _updatePlace(_accommodations[index], value);
                        },
                        onDelete: () {
                          _removeAccommodation(_accommodations[index]);
                        },
                      ),

                    // =================================================
                    // 숙소 추가 버튼
                    // =================================================
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addAccommodation,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          '숙소 추가',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.all(18),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // 이전 → 입출국 정보
            // 다음 → 고정 일정
            // =================================================
            TripBottomNavigation(onPrevious: _goPrevious, onNext: _goNext),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 숙소 데이터
//
// Google Places 객체를 사용하지 않고
// 직접 입력한 숙소명 또는 주소 문자열만 저장합니다.
// ===========================================================

class _AccommodationEntry {
  DateTime? startDate;
  DateTime? endDate;

  String place = '';
}

// ===========================================================
// 숙소 카드
//
// 각 숙소마다 다음 정보를 입력합니다.
//
// - 숙박 시작일
// - 숙박 종료일
// - 숙소명 또는 주소
//
// 우측 상단 삭제 버튼으로 숙소를 삭제할 수 있습니다.
// ===========================================================

class _AccommodationCard extends StatelessWidget {
  final int number;
  final _AccommodationEntry entry;

  final VoidCallback onStartDate;
  final VoidCallback onEndDate;

  final ValueChanged<String> onPlaceChanged;

  final VoidCallback onDelete;

  const _AccommodationCard({
    super.key,
    required this.number,
    required this.entry,
    required this.onStartDate,
    required this.onEndDate,
    required this.onPlaceChanged,
    required this.onDelete,
  });

  // =========================================================
  // 날짜 표시
  //
  // 선택 전:
  // 날짜 선택
  //
  // 선택 후:
  // 2026-10-03
  // =========================================================

  String _dateText(DateTime? date) {
    if (date == null) {
      return '날짜 선택';
    }

    if (TripDraft.instance.isUndated)
      return '${date.difference(TripDraft.instance.inputBase).inDays + 1}일차';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
          // =================================================
          // 숙소 번호 + 삭제
          // =================================================

          Row(
            children: [
              Expanded(
                child: Text(
                  '숙소 $number',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),

              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('삭제'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // =================================================
          // 숙박 기간
          // =================================================
          const Text('숙박 기간', style: TextStyle(fontWeight: FontWeight.w800)),

          const SizedBox(height: 8),

          _AccommodationDateField(
            label: '시작일',
            value: _dateText(entry.startDate),
            selected: entry.startDate != null,
            onTap: onStartDate,
          ),

          const SizedBox(height: 10),

          _AccommodationDateField(
            label: '종료일',
            value: _dateText(entry.endDate),
            selected: entry.endDate != null,
            onTap: onEndDate,
          ),

          const SizedBox(height: 20),

          // =================================================
          // 숙소명 / 주소 직접 입력
          // =================================================
          const Text('숙소 장소', style: TextStyle(fontWeight: FontWeight.w800)),

          const SizedBox(height: 8),

          TextFormField(
            key: ValueKey('accommodation_place_$number'),
            initialValue: entry.place,
            onChanged: onPlaceChanged,
            textInputAction: TextInputAction.done,
            maxLength: 100,
            decoration: InputDecoration(
              counterText: '',
              hintText: '숙소명 또는 주소 입력',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.hotel_rounded,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 숙박 시작일 / 종료일 선택 필드
// ===========================================================

class _AccommodationDateField extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;

  final VoidCallback onTap;

  const _AccommodationDateField({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
