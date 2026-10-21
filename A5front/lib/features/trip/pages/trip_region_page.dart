import '../../../core/widgets/app_dialog_actions.dart';
import 'dart:convert';
import '../../../core/state/island_travel_labels.dart';
import '../widgets/city_selection_map.dart';
import '../../../core/state/city_ordering.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripRegionPage extends StatefulWidget {
  const TripRegionPage({super.key});

  @override
  State<TripRegionPage> createState() => _TripRegionPageState();
}

class _TripRegionPageState extends State<TripRegionPage>
    with DraftAutosave<TripRegionPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.cities = [...selectedCities, ...customCities];
    d.customCities = customCities.toList();
    d.excludeSuburbs = isCityFixed;
    d.pendingCity = customCityController.text;
  }

  // =========================================================
  // 도시 선택 설정
  //
  // 대표 도시와 직접 입력 도시를 합쳐
  // 최대 50개까지 선택할 수 있습니다.
  // =========================================================

  static const int maxSelectedCities = 50;

  // 목록에서 선택한 대표 도시
  final Set<String> selectedCities = {};

  // 사용자가 직접 입력한 도시
  final Set<String> customCities = {};

  final _scrollController = ScrollController();
  final _regionControllers = <String, ExpansibleController>{};
  String? get _anchorCity => itineraryAnchorCity(
    TripDraft.instance.title,
    presetCities,
    [...selectedCities, ...customCities],
  );

  void _revealSelectedRegion(String city, String? previousAnchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final group = regionGroups
          .where((g) => g.cities.contains(city))
          .firstOrNull;
      if (group != null) _regionControllers[group.name]?.expand();
      if (previousAnchor != _anchorCity && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // 도시 고정 여부
  bool isCityFixed = false;

  final TextEditingController customCityController = TextEditingController();

  // =========================================================
  // 일본 9개 권역 + 주요 대도시 / 유명도시
  //
  // 목록에 없는 소도시는 아래 직접 입력 기능을 통해
  // 추가할 수 있습니다.
  // =========================================================

  final List<_RegionGroup> regionGroups = const [
    _RegionGroup(
      name: '홋카이도',
      description: '삿포로, 오타루, 하코다테 등 홋카이도 주요 여행 도시',
      cities: ['삿포로', '오타루', '하코다테', '아사히카와', '후라노'],
    ),

    _RegionGroup(
      name: '도호쿠',
      description: '센다이, 아오모리 등 일본 북동부의 주요 여행 도시',
      cities: ['센다이', '아오모리', '히로사키', '모리오카', '야마가타', '아이즈와카마쓰'],
    ),

    _RegionGroup(
      name: '간토',
      description: '도쿄, 요코하마 등 수도권 중심의 주요 여행 도시',
      cities: ['도쿄', '요코하마', '가마쿠라', '닛코', '가와고에', '지바'],
    ),

    _RegionGroup(
      name: '주부',
      description: '나고야, 가나자와 등 일본 중부의 주요 여행 도시',
      cities: ['나고야', '가나자와', '다카야마', '마쓰모토', '시즈오카', '니가타'],
    ),

    _RegionGroup(
      name: '간사이',
      description: '오사카, 교토, 고베 등 인기 여행 도시',
      cities: ['오사카', '교토', '고베', '나라', '히메지', '와카야마'],
    ),

    _RegionGroup(
      name: '주고쿠',
      description: '히로시마, 오카야마 등 서일본의 주요 여행 도시',
      cities: ['히로시마', '오카야마', '구라시키', '돗토리', '마쓰에', '시모노세키'],
    ),

    _RegionGroup(
      name: '시코쿠',
      description: '마쓰야마, 다카마쓰 등 시코쿠의 주요 여행 도시',
      cities: ['마쓰야마', '다카마쓰', '고치', '도쿠시마', '나루토'],
    ),

    _RegionGroup(
      name: '규슈',
      description: '후쿠오카, 나가사키 등 규슈의 주요 여행 도시',
      cities: ['후쿠오카', '나가사키', '구마모토', '벳푸', '가고시마'],
    ),

    _RegionGroup(
      name: '오키나와',
      description: '나하, 이시가키 등 오키나와의 주요 여행 도시',
      cities: ['나하', '이시가키', '미야코지마', '나고', '오키나와'],
    ),
  ];

  // =========================================================
  // 현재 선택된 전체 도시 개수
  // =========================================================

  int get totalSelectedCityCount => selectedCities.length + customCities.length;

  // =========================================================
  // 앱에 등록되어 있는 모든 대표 도시
  //
  // 직접 입력한 도시가 이미 대표 도시 목록에 있는지
  // 확인할 때 사용합니다.
  // =========================================================

  List<_RegionGroup> get orderedGroups {
    final anchor = itineraryAnchorCity(
      TripDraft.instance.title,
      presetCities,
      TripDraft.instance.cities,
    );
    if (anchor == null) return regionGroups;
    final groups = regionGroups
        .map(
          (g) => _RegionGroup(
            name: g.name,
            description: g.description,
            cities: [...g.cities]..sort((a, b) => compareCities(anchor, a, b)),
          ),
        )
        .toList();
    double distance(_RegionGroup g) => g.cities
        .map((c) => cityDistance(anchor, c))
        .reduce((a, b) => a < b ? a : b);
    groups.sort((a, b) {
      if (a.cities.contains(anchor)) return b.cities.contains(anchor) ? 0 : -1;
      if (b.cities.contains(anchor)) return 1;
      final da = distance(a), db = distance(b);
      final value = da.isFinite && db.isFinite
          ? (da / 10).round().compareTo((db / 10).round())
          : da.compareTo(db);
      return value == 0 ? a.name.compareTo(b.name) : value;
    });
    return groups;
  }

  Set<String> get presetCities {
    return regionGroups.expand((group) => group.cities).toSet();
  }

  @override
  void dispose() {
    saveDraft();
    customCityController.dispose();
    _scrollController.dispose();
    for (final controller in _regionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // =========================================================
  // 대표 도시 선택 / 선택 해제
  // =========================================================

  void _toggleCity(String city) {
    final previousAnchor = _anchorCity;
    // 이미 선택한 도시를 다시 누르면 선택 해제
    if (selectedCities.contains(city)) {
      setState(() {
        selectedCities.remove(city);
      });
      if (_anchorCity != null)
        _revealSelectedRegion(_anchorCity!, previousAnchor);

      return;
    }

    // 대표 도시 + 직접 입력 도시 합산 최대 50개
    if (totalSelectedCityCount >= maxSelectedCities) {
      _showMaximumCityMessage();
      return;
    }

    setState(() {
      selectedCities.add(city);
    });
    _revealSelectedRegion(city, previousAnchor);
  }

  // =========================================================
  // 소도시 직접 입력
  //
  // 실제로 존재하는 일본 도시인지 여부는
  // 추후 백엔드에서 검증합니다.
  // =========================================================

  void _addCustomCity() {
    final previousAnchor = _anchorCity;
    final city = customCityController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // 빈 문자열 방지
    if (city.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('추가할 도시명을 입력해주세요.')));

      return;
    }

    // 한 번에 여러 도시를 넣는 것을 방지
    if (city.contains(',') || city.contains('、') || city.contains('\n')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('도시는 한 번에 하나씩 입력해주세요.')));

      return;
    }

    // 이미 대표 도시로 선택되어 있는 경우
    if (selectedCities.contains(city)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$city은(는) 이미 선택되어 있습니다.')));

      customCityController.clear();

      return;
    }

    // 이미 직접 입력한 도시인 경우
    if (customCities.contains(city)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$city은(는) 이미 추가되어 있습니다.')));

      customCityController.clear();

      return;
    }

    if (totalSelectedCityCount >= maxSelectedCities) {
      _showMaximumCityMessage();
      return;
    }

    // =======================================================
    // 직접 입력한 값이 이미 대표 도시 목록에 있다면
    // customCities가 아닌 selectedCities로 처리
    // =======================================================

    if (presetCities.contains(city)) {
      setState(() {
        selectedCities.add(city);
        customCityController.clear();
      });
      _revealSelectedRegion(city, previousAnchor);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$city은(는) 대표 도시 목록에 있어 선택 목록에 추가했습니다.')),
      );

      return;
    }

    // 목록에 없는 도시는 직접 입력 도시로 저장
    setState(() {
      customCities.add(city);
      customCityController.clear();
    });
    _revealSelectedRegion(city, previousAnchor);
  }

  // =========================================================
  // 하단 선택 목록에서 도시 삭제
  // =========================================================

  void _removeCity(String city) {
    setState(() {
      selectedCities.remove(city);
      customCities.remove(city);
    });
  }

  // =========================================================
  // 최대 선택 개수 안내
  // =========================================================

  void _showMaximumCityMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('도시는 직접 입력한 도시를 포함해 최대 50개까지 선택할 수 있습니다.')),
    );
  }

  // =========================================================
  // 도시 고정 안내
  // =========================================================

  void _showCityFixedInfo() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '도시 고정',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            '이 버튼을 누르면 선택한 도시 외에는 일정에 들어가지 않습니다.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // 페이지 이동
  //
  // 1단계 여행 기간
  //      ↓
  // 2단계 여행 지역
  //      ↓
  // 3단계 입출국 정보
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripPeriod);
  }

  bool _confirmingCities = false;

  Future<void> _goNext() async {
    if (_confirmingCities) return;
    // 대표 도시 또는 직접 입력 도시 중
    // 최소 하나 이상 선택해야 함
    if (totalSelectedCityCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('여행할 도시를 하나 이상 선택해주세요.')));

      return;
    }

    saveDraft();
    final cities = [...selectedCities, ...customCities]..sort();
    final signature = jsonEncode({'cities': cities, 'fixed': isCityFixed});
    if (TripDraft.instance.confirmedCitySelection != signature) {
      _confirmingCities = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('선택한 도시'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: cities
                      .map(
                        (city) => InputChip(
                          label: Text(islandCityLabel(city)),
                          onDeleted: () {
                            _removeCity(city);
                            Navigator.pop(dialogContext, false);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  isCityFixed
                      ? '선택한 도시 안에서만 일정을 만듭니다.'
                      : '일정에 맞춰 근교를 추천할 수 있습니다.',
                ),
              ],
            ),
          ),
          actions: [
            AppDialogActions(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('선택 수정'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('이 도시로 계속'),
                ),
              ],
            ),
          ],
        ),
      );
      _confirmingCities = false;
      if (!mounted || confirmed != true) return;
      TripDraft.instance.confirmedCitySelection = signature;
    }

    context.go(AppRoutes.tripEntryExit);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    customCities.addAll(d.customCities);
    selectedCities.addAll(d.cities.where((c) => !customCities.contains(c)));
    isCityFixed = d.excludeSuburbs;
    customCityController.text = d.pendingCity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 2단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 2),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 2),

                    const SizedBox(height: 16),
                    CitySelectionMap(
                      cities: [...presetCities, ...customCities],
                      selected: {...selectedCities, ...customCities},
                      anchorCity: itineraryAnchorCity(
                        TripDraft.instance.title,
                        presetCities,
                        TripDraft.instance.cities,
                      ),
                      onToggle: (city) {
                        if (customCities.contains(city))
                          _removeCity(city);
                        else
                          _toggleCity(city);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        islandTravelNotice,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '어느 도시로\n떠나시나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '여행하고 싶은 권역을 열어 대표 도시를 선택하거나 목록에 없는 소도시를 직접 입력해주세요.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =================================================
                    // 9개 권역별 대표 도시 목록
                    // =================================================
                    ...orderedGroups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RegionExpansionCard(
                          key: ValueKey(group.name),
                          controller: _regionControllers.putIfAbsent(
                            group.name,
                            ExpansibleController.new,
                          ),
                          group: group,
                          selectedCities: selectedCities,
                          onToggleCity: _toggleCity,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // 목록에 없는 소도시 직접 입력
                    // =================================================
                    _CustomCityInputCard(
                      controller: customCityController,
                      onAdd: _addCustomCity,
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // 현재 선택된 도시 목록 + 도시 고정
            // =================================================

            // =================================================
            // 이전 → 여행 기간
            // 다음 → 입출국 정보
            // =================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: _CityFixedCard(
                value: isCityFixed,
                onChanged: (value) => setState(() => isCityFixed = value),
                onInfoTap: _showCityFixedInfo,
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
// 선택된 도시 하단 표시 영역
//
// 대표 도시와 직접 입력 도시를 모두 Chip으로 표시합니다.
// 직접 입력한 도시에는 연필 아이콘이 표시됩니다.
//
// 도시 고정 설정도 이 영역에 함께 표시합니다.
// ===========================================================

class _CityFixedCard extends StatelessWidget {
  const _CityFixedCard({
    required this.value,
    required this.onChanged,
    required this.onInfoTap,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfoTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '도시 고정',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('선택한 도시 안에서만 일정 생성'),
          ),
        ),
        IconButton(
          onPressed: onInfoTap,
          tooltip: '도시 고정 안내',
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
  );
}

class _CustomCityInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _CustomCityInputCard({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '목록에 없는 소도시',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      '한 번에 한 도시씩 직접 입력할 수 있습니다.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    onAdd();
                  },
                  decoration: InputDecoration(
                    hintText: '예: 가루이자와',
                    prefixIcon: const Icon(Icons.location_on_outlined),
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
              ),

              const SizedBox(width: 10),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '추가',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            '직접 입력한 도시의 실제 존재 여부는 일정 생성 시 서버에서 확인합니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 권역별 대표 도시 펼침 카드
//
// 예:
//
// 간토
// ├ 도쿄
// ├ 요코하마
// ├ 가마쿠라
// └ ...
//
// 각 권역을 펼친 뒤 대표 도시를 개별 선택 / 해제합니다.
// ===========================================================

class _RegionExpansionCard extends StatelessWidget {
  final _RegionGroup group;
  final ExpansibleController controller;
  final Set<String> selectedCities;
  final ValueChanged<String> onToggleCity;

  const _RegionExpansionCard({
    super.key,
    required this.controller,
    required this.group,
    required this.selectedCities,
    required this.onToggleCity,
  });

  @override
  Widget build(BuildContext context) {
    // 해당 권역에서 현재 선택된 도시 개수 계산
    final selectedCount = group.cities
        .where((city) => selectedCities.contains(city))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: controller,
            key: ValueKey(group.name),
            initiallyExpanded: group.cities.any(
              (c) =>
                  TripDraft.instance.title.contains(c) ||
                  selectedCities.contains(c),
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 6,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),

            // =================================================
            // 권역 이름 + 선택된 도시 개수
            // =================================================
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$selectedCount개 선택',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),

            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                group.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),

            // =================================================
            // 해당 권역의 대표 도시 목록
            // =================================================
            children: group.cities.map((city) {
              final selected = selectedCities.contains(city);

              return CheckboxListTile(
                value: selected,
                onChanged: (_) {
                  onToggleCity(city);
                },
                dense: true,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  islandCityLabel(city),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 권역 데이터 모델
//
// 각 권역은
// - 권역명
// - 설명
// - 대표 대도시 / 유명도시
// 정보를 가집니다.
// ===========================================================

class _RegionGroup {
  final String name;
  final String description;
  final List<String> cities;

  const _RegionGroup({
    required this.name,
    required this.description,
    required this.cities,
  });
}
