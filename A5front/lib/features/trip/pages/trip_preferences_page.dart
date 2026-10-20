import 'package:flutter/material.dart';
import '../../mypage/widgets/long_trip_settings_card.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/money_display.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_bottom_navigation.dart';

class TripPreferencesPage extends StatefulWidget {
  const TripPreferencesPage({super.key});
  @override
  State<TripPreferencesPage> createState() => _TripPreferencesPageState();
}

class _Option {
  const _Option(this.name, this.description, this.icon, {this.value});
  final String name, description;
  final IconData icon;
  final String? value;
  String get key => value ?? name;
}

class _TripPreferencesPageState extends State<TripPreferencesPage> {
  final d = TripDraft.instance;
  final pages = PageController();
  int panel = 0;
  bool excludedMode = false;
  @override
  void initState() {
    super.initState();
    d.companions.removeWhere(
      (value) => !companions.any((item) => item.key == value),
    );
  }

  static const companions = [
    _Option('혼자', '나만의 속도로 즐기는 여행', Icons.person_outline),
    _Option('친구', '친구와 함께 즐기는 여행', Icons.people_outline),
    _Option('연인', '둘이 함께 즐기는 여행', Icons.favorite_outline),
    _Option('부모님', '부모님과 함께하는 여행', Icons.elderly_outlined),
    _Option('어린이', '어린이를 동반하는 여행', Icons.child_care),
    _Option('배우자', '배우자와 함께하는 여행', Icons.favorite_border),
  ];
  static const ages = [
    _Option('아동', '0~12세', Icons.child_care),
    _Option('학생', '13~18세', Icons.school_outlined),
    _Option('성인', '19~64세', Icons.person_outline),
    _Option('노약자', '65세 이상', Icons.elderly_outlined),
  ];
  static const themes = [
    _Option('맛집', '현지 음식과 인기 식당 탐방', Icons.restaurant_outlined),
    _Option('쇼핑', '상점가·백화점·기념품 쇼핑', Icons.shopping_bag_outlined),
    _Option('관광', '도시의 대표 명소 둘러보기', Icons.location_city_outlined),
    _Option('힐링', '산책과 편안한 휴식', Icons.spa_outlined),
    _Option('사진', '사진 명소와 감성적인 장소', Icons.photo_camera_outlined),
    _Option('서브컬쳐', '애니메이션·캐릭터·굿즈', Icons.animation_outlined),
    _Option('문화', '사찰·박물관·전통문화 체험', Icons.museum_outlined),
    _Option('자연', '공원·바다·산의 풍경 즐기기', Icons.forest_outlined),
    _Option('야경', '전망대와 도시의 밤 풍경', Icons.nightlight_outlined),
    _Option('온천', '온천과 료칸에서 쉬어가기', Icons.hot_tub_outlined),
    _Option('액티비티', '놀이공원과 다양한 체험', Icons.local_activity_outlined),
    _Option('카페', '카페 탐방과 디저트 즐기기', Icons.local_cafe_outlined),
  ];
  static const transport = [
    _Option(
      '도보·대중교통',
      '전철·버스와 도보를 이용해 이동합니다.',
      Icons.directions_transit_outlined,
      value: '도보 및 대중교통',
    ),
    _Option(
      '렌터카',
      '렌터카로 이동하는 동선으로 구성합니다.',
      Icons.directions_car_outlined,
      value: '차량 렌트',
    ),
  ];
  static const paces = [
    _Option('여유로운', '방문 장소를 줄이고 이동과 휴식에 여유를 둡니다.', Icons.spa_outlined),
    _Option('평범한', '관광·이동·휴식의 균형을 맞춥니다.', Icons.balance_outlined),
    _Option('알찬', '하루에 더 많은 장소를 방문하도록 구성합니다.', Icons.bolt_outlined),
  ];
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void showPanel(int value) {
    setState(() => panel = value);
    if (pages.hasClients)
      pages.animateToPage(
        value,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void chooseCompanion(String name) => setState(() {
    if (name == '혼자') {
      d.companions = d.companions.contains(name) ? [] : [name];
      d.ageGroups.remove('아동');
      if (d.ageGroups.length > 1) d.ageGroups = [d.ageGroups.first];
    } else {
      d.companions.remove('혼자');
      d.companions.contains(name)
          ? d.companions.remove(name)
          : d.companions.add(name);
    }
  });
  void chooseTheme(String name, {bool excluded = false}) {
    if (!excluded && !d.themes.contains(name) && d.themes.length >= 3) {
      message('여행 테마는 최대 3개까지 선택할 수 있습니다.');
      return;
    }
    setState(() {
      final target = excluded ? d.excludedThemes : d.themes;
      target.contains(name) ? target.remove(name) : target.add(name);
      if (target.contains(name))
        (excluded ? d.themes : d.excludedThemes).remove(name);
      if (d.themes.contains('카페')) d.includeSnacks = true;
      d.mealsPerDay = d.mealsPerDay.clamp(1, d.maxMealsPerDay);
    });
  }

  Widget section(
    String title,
    String description,
    List<Widget> children, {
    String? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    ),
  );
  Widget option(
    _Option item,
    bool selected,
    VoidCallback choose, {
    bool enabled = true,
  }) => Semantics(
    button: true,
    selected: selected,
    enabled: enabled,
    child: Material(
      color: !enabled
          ? const Color(0xFFF7F8FA)
          : selected
          ? const Color(0xFFEFF6FF)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? choose : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 23,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 19,
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget choices(
    List<_Option> items,
    List<String> selected,
    void Function(String) choose, {
    bool Function(String)? enabled,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final single =
          constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      Widget tile(_Option o) => option(
        o,
        selected.contains(o.key),
        () => choose(o.key),
        enabled: enabled?.call(o.key) ?? true,
      );
      if (single)
        return Column(
          children: [
            for (final o in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(width: double.infinity, child: tile(o)),
              ),
          ],
        );
      return Column(
        children: [
          for (int i = 0; i < items.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: i + 1 < items.length
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: tile(items[i])),
                          const SizedBox(width: 10),
                          Expanded(child: tile(items[i + 1])),
                        ],
                      ),
                    )
                  : Center(
                      child: SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: tile(items[i]),
                      ),
                    ),
            ),
        ],
      );
    },
  );
  Future<void> pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? d.dailyStart : d.dailyEnd,
      helpText: start ? '숙소 출발 시간' : '숙소 도착 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null && mounted)
      setState(() {
        start ? d.dailyStart = picked : d.dailyEnd = picked;
      });
  }

  Widget timeCard(bool start) => Material(
    color: const Color(0xFFF8FAFC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => pickTime(start),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              start ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              start ? '숙소 출발' : '숙소 도착',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (start ? d.dailyStart : d.dailyEnd).format(context),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '시간 변경',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
    ),
  );
  Widget peopleAndThemes({required bool showCompanion}) => Column(
    children: [
      if (showCompanion)
        section(
          '누구와 함께하나요?',
          '함께하는 사람을 모두 선택하세요. 혼자 여행은 다른 동행자와 함께 선택할 수 없습니다.',
          [
            choices(companions, d.companions, chooseCompanion),
            const Divider(height: 30),
            const Text(
              '여행자 연령대',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              d.companions.contains('혼자')
                  ? '혼자 여행은 아동을 제외한 연령대 하나를 선택할 수 있습니다.'
                  : '함께 여행하는 사람들의 연령대를 모두 선택하세요.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            choices(
              ages,
              d.ageGroups,
              (s) => setState(() {
                if (d.companions.contains('혼자'))
                  d.ageGroups = d.ageGroups.contains(s) ? [] : [s];
                else {
                  d.ageGroups.contains(s)
                      ? d.ageGroups.remove(s)
                      : d.ageGroups.add(s);
                }
              }),
              enabled: (s) => !(s == '아동' && d.companions.contains('혼자')),
            ),
          ],
        ),
      if (!showCompanion)
        section(
          '어떤 여행을 좋아하나요?',
          excludedMode
              ? '금지 테마를 고르세요. 선택한 테마는 추천 후보에서 제외됩니다.'
              : '좋아하는 테마를 최대 3개 선택하세요. 선택한 취향을 중심으로 방문지를 추천합니다.',
          [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('선호 테마'),
                  icon: Icon(Icons.favorite_outline),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('금지 테마'),
                  icon: Icon(Icons.block_outlined),
                ),
              ],
              selected: {excludedMode},
              onSelectionChanged: (values) =>
                  setState(() => excludedMode = values.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            choices(
              themes,
              excludedMode ? d.excludedThemes : d.themes,
              (name) => chooseTheme(name, excluded: excludedMode),
            ),
            Text(
              excludedMode
                  ? '제외한 테마는 선호 테마에서 빠집니다.'
                  : '선호 테마와 제외 테마는 중복해서 선택할 수 없습니다.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          trailing: excludedMode
              ? '${d.excludedThemes.length}개 제외'
              : '${d.themes.length} / 3 · 필수',
        ),
    ],
  );

  Widget daily() => Column(
    children: [
      const TripRestDaysToggle(),
      section(
        '하루를 언제 시작하고 마칠까요?',
        '시작은 숙소를 나오는 시간, 종료는 숙소에 돌아오는 시간입니다. 입출국 날은 항공편 조건에 맞춰 조정합니다.',
        [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: timeCard(true)),
                const SizedBox(width: 12),
                Expanded(child: timeCard(false)),
              ],
            ),
          ),
        ],
      ),
      section('얼마나 여유롭게 둘러볼까요?', '관광지별 체류와 하루 방문량을 조절합니다. 평범한이 기본 선택입니다.', [
        for (final item in paces)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: option(
              item,
              d.pace == item.name,
              () => setState(() => d.pace = item.name),
            ),
          ),
      ]),
      section('하루에 몇 번 식사할까요?', '간식을 제외한 식사 횟수입니다. 짧은 입출국 날은 가능한 식사만 배치합니다.', [
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 1; i <= d.maxMealsPerDay; i++)
                SizedBox(
                  width:
                      (c.maxWidth - 8 * (d.maxMealsPerDay - 1)) /
                      d.maxMealsPerDay,
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Center(child: Text('$i회')),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    selected: d.mealsPerDay == i,
                    onSelected: (_) => setState(() => d.mealsPerDay = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          d.maxMealsPerDay == 5
              ? '맛집 테마를 선택해 최대 5회까지 고를 수 있습니다.'
              : '맛집 테마를 선택하면 최대 5회까지 고를 수 있습니다.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const Divider(height: 30),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '카페·간식도 들르기',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: const Text(
            '식사 사이에 카페와 디저트 방문도 추천합니다. 카페 테마를 고르면 자동 선택됩니다.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          value: d.includeSnacks,
          onChanged: (v) => setState(() => d.includeSnacks = v),
        ),
      ]),
    ],
  );
  Future<void> generate() async {
    if (d.themes.isEmpty) {
      showPanel(0);
      message('여행 테마를 하나 이상 선택해주세요.');
      return;
    }
    if (d.transport == null) {
      showPanel(2);
      message('주요 이동수단을 선택해주세요.');
      return;
    }
    if (d.dailyEnd.hour * 60 + d.dailyEnd.minute <=
        d.dailyStart.hour * 60 + d.dailyStart.minute) {
      showPanel(3);
      message('하루 종료 시간은 시작 시간보다 늦어야 합니다.');
      return;
    }
    try {
      d.toRequest();
      final accepted = await showAppConfirmDialog(
        context: context,
        title: '일정을 생성할까요?',
        message: d.defaultHotelBudgetCurrency == 'JPY'
            ? '설정한 조건으로 일정을 생성합니다. 금액은 엔화로 표시합니다.'
            : MoneyDisplay.roundingNotice,
        confirmText: '일정 생성',
      );
      if (!mounted || !accepted) return;
      context.go(AppRoutes.loading);
    } on FormatException catch (e) {
      message(e.message);
    }
  }

  Widget tabButton(int i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Semantics(
      selected: panel == i,
      button: true,
      child: Material(
        color: panel == i ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPanel(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Text(
              ['테마', '동행', '이동', '하루 일정'][i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: panel == i ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          const TripStepHeader(currentStep: 6, title: '여행 취향과 하루 일정'),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            for (int i = 0; i < 4; i++)
                              Expanded(child: tabButton(i)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: pages,
                        itemCount: 4,
                        onPageChanged: (value) => setState(() => panel = value),
                        itemBuilder: (context, index) => SingleChildScrollView(
                          key: PageStorageKey('preference-panel-$index'),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: index == 0
                              ? peopleAndThemes(showCompanion: false)
                              : index == 1
                              ? peopleAndThemes(showCompanion: true)
                              : index == 2
                              ? section(
                                  '어떻게 이동하나요?',
                                  '여행 중 주로 사용할 이동수단을 하나 선택하세요. 선택한 수단으로 동선과 이동 정보를 구성합니다.',
                                  [
                                    choices(
                                      transport,
                                      d.transport == null ? [] : [d.transport!],
                                      (s) => setState(() => d.transport = s),
                                    ),
                                  ],
                                  trailing: '필수',
                                )
                              : daily(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            color: Colors.white,
            child: Text(
              '${d.themes.isEmpty ? '테마 선택 필요' : d.themes.join(' · ')}  /  ${d.transport == null
                  ? '이동수단 선택 필요'
                  : d.transport == '차량 렌트'
                  ? '렌터카'
                  : '대중교통'}  /  식사 ${d.mealsPerDay}회',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          TripBottomNavigation(
            onPrevious: () => context.go(AppRoutes.tripFixedSchedule),
            onNext: generate,
            nextText: '일정 생성',
          ),
        ],
      ),
    ),
  );
}
