import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/city_airports.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripEntryExitPage extends StatefulWidget {
  const TripEntryExitPage({super.key});

  @override
  State<TripEntryExitPage> createState() => _TripEntryExitPageState();
}

class _TripEntryExitPageState extends State<TripEntryExitPage>
    with DraftAutosave<TripEntryExitPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.entryAirport = entryAirport;
    d.exitAirport = exitAirport;
    d.entryTime = entryTime;
    d.exitTime = exitTime;
  }

  String? entryAirport;
  String? exitAirport;

  TimeOfDay? entryTime;
  TimeOfDay? exitTime;

  // =========================================================
  // 일본 국제선 이용 공항 42개
  //
  // 기존 36개 공항 +
  // 아사히카와, 쇼나이, 이즈모, 야마구치우베,
  // 신슈 마쓰모토, 구시로 공항을 포함합니다.
  //
  // 9개 권역별로 분류해 공항 선택 화면에 표시합니다.
  // =========================================================

  final List<_AirportGroup> airportGroups = const [
    _AirportGroup(
      name: '홋카이도',
      airports: ['신치토세공항', '하코다테공항', '오비히로공항', '아사히카와공항', '구시로공항'],
    ),

    _AirportGroup(
      name: '도호쿠',
      airports: ['센다이공항', '아키타공항', '아오모리공항', '하나마키공항', '후쿠시마공항', '쇼나이공항'],
    ),

    _AirportGroup(name: '간토', airports: ['하네다공항', '나리타국제공항', '이바라키공항']),

    _AirportGroup(
      name: '주부',
      airports: [
        '중부국제공항(센트레아)',
        '도야마공항',
        '코마츠공항',
        '니가타공항',
        '시즈오카공항',
        '신슈 마쓰모토공항',
      ],
    ),

    _AirportGroup(name: '간사이', airports: ['간사이국제공항', '고베공항']),

    _AirportGroup(
      name: '주고쿠',
      airports: ['요나고공항', '오카야마공항', '히로시마공항', '이즈모공항', '야마구치우베공항'],
    ),

    _AirportGroup(
      name: '시코쿠',
      airports: ['타카마츠공항', '마쓰야마공항', '고치공항', '도쿠시마공항'],
    ),

    _AirportGroup(
      name: '규슈',
      airports: [
        '후쿠오카공항',
        '기타큐슈공항',
        '사가공항',
        '오이타공항',
        '구마모토공항',
        '나가사키공항',
        '미야자키공항',
        '가고시마공항',
      ],
    ),

    _AirportGroup(name: '오키나와', airports: ['나하공항', '시모지시마공항', '이시가키공항']),
  ];

  // =========================================================
  // 입국 / 출국 공항 선택
  //
  // BottomSheet를 열어 42개 공항 중 하나를 선택합니다.
  // 공항명뿐 아니라 권역명으로도 검색할 수 있습니다.
  // =========================================================

  Future<void> _selectAirport({
    required String title,
    required ValueChanged<String> onSelected,
  }) async {
    if (CityAirports.forCities(TripDraft.instance.cities).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택한 도시의 공항 연결 정보가 없습니다. 지역 단계에서 인근 대표 도시를 함께 선택해주세요.'),
        ),
      );
      return;
    }
    final selectedAirport = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return _AirportSearchBottomSheet(
          title: title,
          airportGroups: airportGroups
              .map(
                (group) => _AirportGroup(
                  name: group.name,
                  airports: group.airports
                      .where(
                        CityAirports.forCities(
                          TripDraft.instance.cities,
                        ).contains,
                      )
                      .toList(),
                ),
              )
              .where((group) => group.airports.isNotEmpty)
              .toList(),
        );
      },
    );

    if (selectedAirport != null) {
      onSelected(selectedAirport);
    }
  }

  // =========================================================
  // 입국 / 출국 시간 선택
  //
  // 현재 단계에서는 시간만 저장합니다.
  //
  // 당일치기 여행에서
  // "출국시간 > 입국시간" 검증은
  // 추후 Riverpod으로 1단계 날짜 정보와 연결한 뒤 처리합니다.
  // =========================================================

  Future<void> _selectTime({
    required TimeOfDay? initialTime,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      helpText: '시간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (selectedTime != null) {
      onSelected(selectedTime);
    }
  }

  // =========================================================
  // 선택된 시간 표시
  //
  // 오전 / 오후 12시간 형식으로 표시합니다.
  //
  // 예:
  // 오전 9:30
  // 오후 3:00
  // =========================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '시간 선택';
    }

    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = _hourOfPeriod(hour);

    return '$period $displayHour:$minute';
  }

  int _hourOfPeriod(int hour) {
    if (hour == 0) {
      return 12;
    }

    if (hour > 12) {
      return hour - 12;
    }

    return hour;
  }

  // =========================================================
  // 입국 / 출국 정보 전체 초기화
  //
  // 각 카드 우측 상단 X 버튼을 누르면
  // 해당 카드의 공항과 시간을 한 번에 지웁니다.
  //
  // 입국 정보 초기화:
  // - 입국 공항
  // - 입국 시간
  //
  // 출국 정보 초기화:
  // - 출국 공항
  // - 출국 시간
  // =========================================================

  void _clearEntryInfo() {
    setState(() {
      entryAirport = null;
      entryTime = null;
    });
  }

  void _clearExitInfo() {
    setState(() {
      exitAirport = null;
      exitTime = null;
    });
  }

  // =========================================================
  // 페이지 이동
  //
  // 변경된 흐름:
  //
  // 2단계 여행 지역
  //      ↓
  // 3단계 입출국 정보
  //      ↓
  // 4단계 숙소
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripRegion);
  }

  Future<void> _goNext() async {
    saveDraft();
    context.go(AppRoutes.tripAccommodation);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    entryAirport = d.entryAirport;
    exitAirport = d.exitAirport;
    entryTime = d.entryTime;
    exitTime = d.exitTime;
    final allowed = CityAirports.forCities(d.cities);
    if (!allowed.contains(entryAirport)) {
      entryAirport = null;
      entryTime = null;
    }
    if (!allowed.contains(exitAirport)) {
      exitAirport = null;
      exitTime = null;
    }
    saveDraft();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 3단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 3),

            const Padding(
              padding: EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: TripStepIndicator(currentStep: 3),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '입출국 정보를 입력해주세요',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '입국·출국 공항은 선택 사항입니다. 선택하지 않은 공항은 일정의 시작·종료 지점에 포함하지 않습니다. 숙박 일수만 정했다면 다음 단계에서 시작일을 선택합니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // 입국 정보
                    // =================================================
                    _EntryExitCard(
                      title: '입국 정보',
                      airportLabel: '입국 공항',
                      airportValue: entryAirport,
                      timeLabel: '입국 예정 시간',
                      timeValue: entryAirport != null && entryTime == null
                          ? '하루 시작 시간 적용'
                          : _formatTime(entryTime),

                      onAirportTap: () {
                        _selectAirport(
                          title: '입국 공항 선택',
                          onSelected: (airport) {
                            setState(() {
                              entryAirport = airport;
                            });
                          },
                        );
                      },

                      onTimeTap: () {
                        _selectTime(
                          initialTime: entryTime,
                          onSelected: (time) {
                            setState(() {
                              entryTime = time;
                            });
                          },
                        );
                      },

                      // 공항이나 시간 중 하나라도 입력되어 있으면
                      // 카드 우측 상단 X 버튼 표시
                      onClear: entryAirport != null || entryTime != null
                          ? _clearEntryInfo
                          : null,
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // 출국 정보
                    // =================================================
                    _EntryExitCard(
                      title: '출국 정보',
                      airportLabel: '출국 공항',
                      airportValue: exitAirport,
                      timeLabel: '출국 예정 시간',
                      timeValue: exitAirport != null && exitTime == null
                          ? '하루 종료 시간 적용'
                          : _formatTime(exitTime),

                      onAirportTap: () {
                        _selectAirport(
                          title: '출국 공항 선택',
                          onSelected: (airport) {
                            setState(() {
                              exitAirport = airport;
                            });
                          },
                        );
                      },

                      onTimeTap: () {
                        _selectTime(
                          initialTime: exitTime,
                          onSelected: (time) {
                            setState(() {
                              exitTime = time;
                            });
                          },
                        );
                      },

                      // 공항이나 시간 중 하나라도 입력되어 있으면
                      // 카드 우측 상단 X 버튼 표시
                      onClear: exitAirport != null || exitTime != null
                          ? _clearExitInfo
                          : null,
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // 입출국 정보 안내
                    //
                    // 현재 입출국 정보는 필수값으로 막지 않습니다.
                    // 추후 입력하면 일정이 달라질 수 있음을 안내합니다.
                    // =================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              '공항을 선택한 경우에만 해당 공항에서 일정을 시작하거나 종료합니다.',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // 이전 → 여행 지역
            // 다음 → 숙소
            // =================================================
            TripBottomNavigation(onPrevious: _goPrevious, onNext: _goNext),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 입국 / 출국 정보 카드
//
// 각 카드에는 다음 정보가 표시됩니다.
//
// - 선택한 공항
// - 선택한 시간
//
// 카드 우측 상단 X 버튼으로
// 해당 카드의 공항과 시간을 한 번에 초기화합니다.
// ===========================================================

class _EntryExitCard extends StatelessWidget {
  final String title;

  final String airportLabel;
  final String? airportValue;

  final String timeLabel;
  final String timeValue;

  final VoidCallback onAirportTap;
  final VoidCallback onTimeTap;

  final VoidCallback? onClear;

  const _EntryExitCard({
    required this.title,
    required this.airportLabel,
    required this.airportValue,
    required this.timeLabel,
    required this.timeValue,
    required this.onAirportTap,
    required this.onTimeTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          // 카드 제목 + 전체 초기화 버튼
          // =================================================

          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              if (onClear != null)
                IconButton(
                  tooltip: '입력 내용 지우기',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 21,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // =================================================
          // 공항 선택
          // =================================================
          _SelectField(
            label: airportLabel,
            value: airportValue ?? '공항 선택',
            icon: Icons.local_airport_rounded,
            isPlaceholder: airportValue == null,
            onTap: onAirportTap,
          ),

          const SizedBox(height: 12),

          // =================================================
          // 시간 선택
          // =================================================
          _SelectField(
            label: timeLabel,
            value: timeValue,
            icon: Icons.access_time_rounded,
            isPlaceholder: timeValue == '시간 선택',
            onTap: onTimeTap,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 공항 / 시간 선택용 공통 필드
//
// 공항 선택과 시간 선택에서 동일한 UI를 사용합니다.
// ===========================================================

class _SelectField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  final bool isPlaceholder;
  final VoidCallback onTap;

  const _SelectField({
    required this.label,
    required this.value,
    required this.icon,
    required this.isPlaceholder,
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
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),

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
                        color: isPlaceholder
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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

// ===========================================================
// 국제공항 선택 BottomSheet
//
// 검색어가 없을 때:
// 9개 권역별로 42개 공항을 모두 표시
//
// 검색어가 있을 때:
// 공항명 또는 권역명 기준으로 필터링
//
// 예:
// "나리타" → 나리타국제공항
// "홋카이도" → 홋카이도 권역 공항 전체
// ===========================================================

class _AirportSearchBottomSheet extends StatefulWidget {
  final String title;
  final List<_AirportGroup> airportGroups;

  const _AirportSearchBottomSheet({
    required this.title,
    required this.airportGroups,
  });

  @override
  State<_AirportSearchBottomSheet> createState() =>
      _AirportSearchBottomSheetState();
}

class _AirportSearchBottomSheetState extends State<_AirportSearchBottomSheet> {
  final TextEditingController controller = TextEditingController();

  String keyword = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // =========================================================
  // 검색 결과
  //
  // 권역명이 검색어와 일치하면
  // 해당 권역의 모든 공항을 표시합니다.
  //
  // 그 외에는 공항명에 검색어가 포함된 공항만 표시합니다.
  // =========================================================

  List<_AirportGroup> get filteredGroups {
    final query = keyword.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.airportGroups;
    }

    final results = <_AirportGroup>[];

    for (final group in widget.airportGroups) {
      final groupMatches = group.name.toLowerCase().contains(query);

      final matchedAirports = groupMatches
          ? group.airports
          : group.airports
                .where((airport) => airport.toLowerCase().contains(query))
                .toList();

      if (matchedAirports.isNotEmpty) {
        results.add(_AirportGroup(name: group.name, airports: matchedAirports));
      }
    }

    return results;
  }

  void _filter(String value) {
    setState(() {
      keyword = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final groups = filteredGroups;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // BottomSheet 상단 드래그 표시
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            // =================================================
            // 제목 + 닫기 버튼
            // =================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // =================================================
            // 공항 검색
            // =================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: TextField(
                controller: controller,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: '공항 또는 지역 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
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
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // 검색 결과 / 권역별 공항 목록
            // =================================================
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      itemCount: groups.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groups[groupIndex];

                        return _AirportGroupSection(
                          group: group,
                          onSelected: (airport) {
                            Navigator.pop(context, airport);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 권역별 공항 목록
//
// 권역명 아래에 해당 권역의 공항을 표시합니다.
// ===========================================================

class _AirportGroupSection extends StatelessWidget {
  final _AirportGroup group;
  final ValueChanged<String> onSelected;

  const _AirportGroupSection({required this.group, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================================================
          // 권역명 + 현재 표시되는 공항 수
          // =================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  '${group.airports.length}개',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // 해당 권역 공항 목록
          // =================================================
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < group.airports.length; i++) ...[
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.local_airport_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        group.airports[i],
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () {
                        onSelected(group.airports[i]);
                      },
                    ),
                  ),

                  if (i < group.airports.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 공항 권역 데이터 모델
//
// 각 권역은
// - 권역명
// - 권역에 속한 공항 목록
// 정보를 가집니다.
// ===========================================================

class _AirportGroup {
  final String name;
  final List<String> airports;

  const _AirportGroup({required this.name, required this.airports});
}
