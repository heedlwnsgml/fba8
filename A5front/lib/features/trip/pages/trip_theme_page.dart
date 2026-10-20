import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripThemePage extends StatefulWidget {
  const TripThemePage({super.key});

  @override
  State<TripThemePage> createState() => _TripThemePageState();
}

// ===========================================================
// 현재 선택 모드
//
// preferred : 일정에 적극 반영하고 싶은 선호 테마
// excluded  : 일정에서 완전히 제외하고 싶은 테마
// ===========================================================

enum _ThemeSelectionMode { preferred, excluded }

class _TripThemePageState extends State<TripThemePage>
    with DraftAutosave<TripThemePage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.themes = selectedThemes.toList();
    d.excludedThemes = excludedThemes.toList();
    if (selectedThemes.contains('카페')) d.includeSnacks = true;
  }

  // 선호 테마는 기존과 동일하게 최대 3개
  static const int maxThemeSelection = 3;

  // =========================================================
  // 테마 선택 상태
  //
  // selectedThemes:
  // AI가 적극적으로 추천할 선호 테마
  //
  // excludedThemes:
  // 일정 추천 후보에서 완전히 제외할 테마
  // =========================================================

  final Set<String> selectedThemes = {};
  final Set<String> excludedThemes = {};

  _ThemeSelectionMode selectionMode = _ThemeSelectionMode.preferred;

  // =========================================================
  // 기존 12개 테마
  // =========================================================

  final List<_ThemeItem> themes = const [
    _ThemeItem(
      name: '맛집',
      description: '현지 음식과 인기 맛집 탐방',
      icon: Icons.restaurant_rounded,
    ),
    _ThemeItem(
      name: '쇼핑',
      description: '상점가, 백화점, 기념품 쇼핑',
      icon: Icons.shopping_bag_rounded,
    ),
    _ThemeItem(
      name: '관광',
      description: '대표 명소와 유명 관광지 방문',
      icon: Icons.location_city_rounded,
    ),
    _ThemeItem(
      name: '힐링',
      description: '여유로운 산책과 편안한 휴식',
      icon: Icons.spa_rounded,
    ),
    _ThemeItem(
      name: '사진',
      description: '사진 명소와 감성적인 장소',
      icon: Icons.photo_camera_rounded,
    ),
    _ThemeItem(
      name: '서브컬쳐',
      description: '애니메이션, 캐릭터, 굿즈 명소',
      icon: Icons.animation_rounded,
    ),
    _ThemeItem(
      name: '문화',
      description: '사찰, 박물관, 전통 문화 체험',
      icon: Icons.temple_buddhist_rounded,
    ),
    _ThemeItem(
      name: '자연',
      description: '공원, 바다, 산 등 자연 명소',
      icon: Icons.park_rounded,
    ),
    _ThemeItem(
      name: '야경',
      description: '전망대와 야경 명소 감상',
      icon: Icons.nightlight_round,
    ),
    _ThemeItem(
      name: '온천',
      description: '온천과 료칸에서 즐기는 휴식',
      icon: Icons.hot_tub_rounded,
    ),
    _ThemeItem(
      name: '액티비티',
      description: '체험, 놀이공원, 활동 중심 여행',
      icon: Icons.local_activity_rounded,
    ),
    _ThemeItem(
      name: '카페',
      description: '카페 탐방과 디저트 즐기기',
      icon: Icons.local_cafe_rounded,
    ),
  ];

  // =========================================================
  // 선호 / 제외 모드 변경
  // =========================================================

  void _changeSelectionMode(_ThemeSelectionMode mode) {
    setState(() {
      selectionMode = mode;
    });
  }

  // =========================================================
  // 선호 테마 선택 / 해제
  //
  // - 최대 3개
  // - 제외 테마와 중복 선택 불가
  // =========================================================

  void _togglePreferredTheme(String theme) {
    // 이미 선호 테마라면 해제
    if (selectedThemes.contains(theme)) {
      setState(() {
        selectedThemes.remove(theme);
      });
      return;
    }

    // 제외 테마로 선택된 항목은 선호 테마로 중복 선택 불가
    if (excludedThemes.contains(theme)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 제외 테마로 선택한 항목입니다.')));
      return;
    }

    // 기존 최대 3개 제한 유지
    if (selectedThemes.length >= maxThemeSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선호 테마는 최대 3개까지 선택할 수 있습니다.')),
      );
      return;
    }

    setState(() {
      selectedThemes.add(theme);
    });
  }

  // =========================================================
  // 제외 테마 선택 / 해제
  //
  // - 선택 개수 제한 없음
  // - 선호 테마와 중복 선택 불가
  // =========================================================

  void _toggleExcludedTheme(String theme) {
    // 이미 제외 테마라면 해제
    if (excludedThemes.contains(theme)) {
      setState(() {
        excludedThemes.remove(theme);
      });
      return;
    }

    // 선호 테마로 선택된 항목은 제외 테마로 중복 선택 불가
    if (selectedThemes.contains(theme)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 선호 테마로 선택한 항목입니다.')));
      return;
    }

    setState(() {
      excludedThemes.add(theme);
    });
  }

  // =========================================================
  // 현재 모드에 따라 테마 선택
  // =========================================================

  void _toggleTheme(String theme) {
    if (selectionMode == _ThemeSelectionMode.preferred) {
      _togglePreferredTheme(theme);
    } else {
      _toggleExcludedTheme(theme);
    }
  }

  // =========================================================
  // 다음 단계
  //
  // 선호 테마는 기존과 동일하게 최소 1개 필수입니다.
  // 제외 테마는 선택 사항입니다.
  // =========================================================

  void _goNext() {
    if (selectedThemes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선호 테마를 하나 이상 선택해주세요.')));
      return;
    }

    context.go(AppRoutes.tripTransport);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    selectedThemes.addAll(d.themes);
    excludedThemes.addAll(d.excludedThemes);
  }

  @override
  Widget build(BuildContext context) {
    final isPreferredMode = selectionMode == _ThemeSelectionMode.preferred;

    final currentSelectedThemes = isPreferredMode
        ? selectedThemes
        : excludedThemes;

    final selectionColor = isPreferredMode
        ? AppColors.primary
        : Colors.red.shade600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 7단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 7),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 7),

                    const SizedBox(height: 34),

                    Text(
                      '어떤 여행을\n원하시나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '원하는 테마와 일정에서 제외하고 싶은 테마를 설정해주세요.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // 선호 테마 / 제외 테마 전환 버튼
                    // =================================================
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeModeButton(
                            title: '선호 테마',
                            icon: Icons.favorite_rounded,
                            selected:
                                selectionMode == _ThemeSelectionMode.preferred,
                            selectedColor: AppColors.primary,
                            onTap: () {
                              _changeSelectionMode(
                                _ThemeSelectionMode.preferred,
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _ThemeModeButton(
                            title: '제외 테마',
                            icon: Icons.block_rounded,
                            selected:
                                selectionMode == _ThemeSelectionMode.excluded,
                            selectedColor: Colors.red.shade600,
                            onTap: () {
                              _changeSelectionMode(
                                _ThemeSelectionMode.excluded,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // =================================================
                    // 현재 선택 모드 설명
                    // =================================================
                    Row(
                      children: [
                        Icon(
                          isPreferredMode
                              ? Icons.favorite_rounded
                              : Icons.block_rounded,
                          color: selectionColor,
                          size: 22,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          isPreferredMode ? '선호 테마' : '제외 테마',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      isPreferredMode
                          ? '일정에 적극적으로 반영하고 싶은 테마를 최대 3개까지 선택해주세요.'
                          : '일정에 절대 포함하고 싶지 않은 테마를 선택해주세요. 선택 개수에는 제한이 없습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // 현재 모드 선택 결과
                    // =================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectionColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentSelectedThemes.isEmpty
                                  ? isPreferredMode
                                        ? '선호 테마를 선택해주세요.'
                                        : '제외할 테마가 없습니다.'
                                  : isPreferredMode
                                  ? '선호 테마: ${currentSelectedThemes.join(', ')}'
                                  : '제외 테마: ${currentSelectedThemes.join(', ')}',
                              style: TextStyle(
                                color: currentSelectedThemes.isEmpty
                                    ? AppColors.textSecondary
                                    : selectionColor,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            isPreferredMode
                                ? '${selectedThemes.length}/$maxThemeSelection'
                                : '${excludedThemes.length}개',
                            style: TextStyle(
                              color: selectionColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =================================================
                    // 테마 목록
                    //
                    // 선호 / 제외 모드에서 같은 12개 카드 목록을
                    // 그대로 재사용합니다.
                    // =================================================
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: themes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.92,
                          ),
                      itemBuilder: (context, index) {
                        final theme = themes[index];

                        final selected = currentSelectedThemes.contains(
                          theme.name,
                        );

                        // 반대쪽 모드에서 이미 선택되어 있는지 표시
                        final selectedInOtherMode = isPreferredMode
                            ? excludedThemes.contains(theme.name)
                            : selectedThemes.contains(theme.name);

                        return _ThemeCard(
                          theme: theme,
                          selected: selected,
                          selectedInOtherMode: selectedInOtherMode,
                          selectionColor: selectionColor,
                          selectionMode: selectionMode,
                          onTap: () {
                            _toggleTheme(theme.name);
                          },
                        );
                      },
                    ),

                    // =================================================
                    // 전체 선택 결과 요약
                    // =================================================
                    if (selectedThemes.isNotEmpty ||
                        excludedThemes.isNotEmpty) ...[
                      const SizedBox(height: 26),

                      _ThemeResultSummary(
                        selectedThemes: selectedThemes,
                        excludedThemes: excludedThemes,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // =================================================
            // 이전 → 동행자
            // 다음 → 이동수단
            // =================================================
            TripBottomNavigation(
              onPrevious: () {
                context.go(AppRoutes.tripCompanion);
              },
              onNext: _goNext,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 선호 / 제외 모드 전환 버튼
// ===========================================================

class _ThemeModeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor.withOpacity(0.08) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? selectedColor : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? selectedColor : AppColors.textSecondary,
                size: 20,
              ),

              const SizedBox(width: 7),

              Text(
                title,
                style: TextStyle(
                  color: selected ? selectedColor : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 테마 카드
//
// 선호 모드:
// 선택 시 파란색
//
// 제외 모드:
// 선택 시 빨간색
//
// 반대 모드에서 이미 선택된 테마는
// 회색 상태로 표시합니다.
// ===========================================================

class _ThemeCard extends StatelessWidget {
  final _ThemeItem theme;
  final bool selected;
  final bool selectedInOtherMode;
  final Color selectionColor;
  final _ThemeSelectionMode selectionMode;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.selectedInOtherMode,
    required this.selectionColor,
    required this.selectionMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectionColor : AppColors.textSecondary;

    return Material(
      color: selectedInOtherMode
          ? AppColors.border.withOpacity(0.18)
          : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? selectionColor : AppColors.border,
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  if (!selectedInOtherMode)
                    BoxShadow(
                      color: selected
                          ? selectionColor.withOpacity(0.12)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      theme.icon,
                      color: selectedInOtherMode
                          ? AppColors.textSecondary.withOpacity(0.55)
                          : color,
                      size: 30,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    theme.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? selectionColor
                          : selectedInOtherMode
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    theme.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selectedInOtherMode
                          ? AppColors.textSecondary.withOpacity(0.6)
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // =================================================
            // 현재 모드에서 선택된 테마 표시
            // =================================================
            if (selected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selectionColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selectionMode == _ThemeSelectionMode.preferred
                        ? Icons.check_rounded
                        : Icons.block_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

            // =================================================
            // 반대 모드에서 이미 선택된 테마 표시
            // =================================================
            if (selectedInOtherMode)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 선호 / 제외 테마 전체 결과 요약
// ===========================================================

class _ThemeResultSummary extends StatelessWidget {
  final Set<String> selectedThemes;
  final Set<String> excludedThemes;

  const _ThemeResultSummary({
    required this.selectedThemes,
    required this.excludedThemes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택 결과',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 14),

          _ThemeSummaryRow(
            icon: Icons.favorite_rounded,
            title: '선호 테마',
            value: selectedThemes.isEmpty
                ? '선택 안 함'
                : selectedThemes.join(', '),
            color: AppColors.primary,
          ),

          const SizedBox(height: 12),

          _ThemeSummaryRow(
            icon: Icons.block_rounded,
            title: '제외 테마',
            value: excludedThemes.isEmpty
                ? '선택 안 함'
                : excludedThemes.join(', '),
            color: Colors.red.shade600,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 결과 요약 행
// ===========================================================

class _ThemeSummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ThemeSummaryRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),

        const SizedBox(width: 8),

        SizedBox(
          width: 70,
          child: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// 테마 데이터 모델
// ===========================================================

class _ThemeItem {
  final String name;
  final String description;
  final IconData icon;

  const _ThemeItem({
    required this.name,
    required this.description,
    required this.icon,
  });
}
