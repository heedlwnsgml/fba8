import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_step_indicator.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_bottom_navigation.dart';

class TripCompanionPage extends StatefulWidget {
  const TripCompanionPage({super.key});

  @override
  State<TripCompanionPage> createState() => _TripCompanionPageState();
}

class _TripCompanionPageState extends State<TripCompanionPage>
    with DraftAutosave<TripCompanionPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.companions = selectedCompanions.toList();
    d.ageGroups = selectedAgeGroups.toList();
  }

  final Set<String> selectedCompanions = {};
  final Set<String> selectedAgeGroups = {};

  final List<_CompanionItem> companions = const [
    _CompanionItem(
      name: '혼자',
      description: '나만의 속도로 즐기는 여행',
      icon: Icons.person_rounded,
    ),
    _CompanionItem(
      name: '친구',
      description: '친구와 함께 즐기는 자유로운 여행',
      icon: Icons.groups_rounded,
    ),
    _CompanionItem(
      name: '연인',
      description: '연인과 함께하는 여행',
      icon: Icons.favorite_rounded,
    ),
    _CompanionItem(
      name: '부모님',
      description: '부모님과 함께하는 편안한 여행',
      icon: Icons.elderly_rounded,
    ),
    _CompanionItem(
      name: '어린이',
      description: '어린이와 함께하는 여행',
      icon: Icons.child_care_rounded,
    ),
    _CompanionItem(
      name: '배우자',
      description: '배우자와 함께하는 여행',
      icon: Icons.favorite_border_rounded,
    ),
  ];

  final List<_AgeGroupItem> ageGroups = const [
    _AgeGroupItem(
      name: '아동',
      range: '0세 ~ 12세',
      icon: Icons.child_care_rounded,
    ),
    _AgeGroupItem(name: '학생', range: '13세 ~ 18세', icon: Icons.school_rounded),
    _AgeGroupItem(name: '성인', range: '19세 ~ 64세', icon: Icons.person_rounded),
    _AgeGroupItem(name: '노약자', range: '65세 이상', icon: Icons.elderly_rounded),
  ];

  bool get _isSoloSelected {
    return selectedCompanions.contains('혼자');
  }

  bool get _hasOtherCompanionSelected {
    return selectedCompanions.any((companion) => companion != '혼자');
  }

  void _toggleCompanion(String companion) {
    final isSelected = selectedCompanions.contains(companion);

    // 이미 선택한 항목은 언제든 해제 가능
    if (isSelected) {
      setState(() {
        selectedCompanions.remove(companion);
      });
      return;
    }

    // 혼자가 아닌 동행자가 선택된 상태에서는 혼자 선택 불가
    if (companion == '혼자' && _hasOtherCompanionSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 동행자가 선택되어 있어 혼자를 선택할 수 없습니다.')),
      );
      return;
    }

    // 혼자가 선택된 상태에서는 다른 동행자 선택 불가
    if (companion != '혼자' && _isSoloSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('혼자 여행을 선택한 경우 다른 동행자를 선택할 수 없습니다.')),
      );
      return;
    }

    setState(() {
      selectedCompanions.add(companion);
      if (companion == '혼자') selectedAgeGroups.remove('아동');
      if (companion == '혼자' && selectedAgeGroups.length > 1) {
        final retained = selectedAgeGroups.first;
        selectedAgeGroups
          ..clear()
          ..add(retained);
      }
    });
  }

  void _toggleAgeGroup(String ageGroup) {
    if (_isSoloSelected && ageGroup == '아동') return;
    setState(() {
      if (selectedAgeGroups.contains(ageGroup)) {
        selectedAgeGroups.remove(ageGroup);
      } else {
        if (_isSoloSelected) selectedAgeGroups.clear();
        selectedAgeGroups.add(ageGroup);
      }
    });
  }

  void _goNext() {
    if (selectedCompanions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('동행자를 하나 이상 선택해주세요.')));
      return;
    }

    context.go(AppRoutes.tripTheme);
  }

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    selectedCompanions.addAll(d.companions);
    selectedAgeGroups.addAll(d.ageGroups);
    if (_isSoloSelected) {
      selectedAgeGroups.remove('아동');
      saveDraft();
    }
    if (_isSoloSelected && selectedAgeGroups.length > 1) {
      final retained = selectedAgeGroups.first;
      selectedAgeGroups
        ..clear()
        ..add(retained);
      saveDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TripStepHeader(currentStep: 6),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 6),

                    const SizedBox(height: 34),

                    Text(
                      '누구와 함께\n여행하시나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '동행자를 선택하면 이동 거리, 식사, 휴식 시간 등을 고려해 일정을 추천합니다.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '혼자는 단독으로만 선택할 수 있으며, 그 외 동행자는 중복 선택할 수 있습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    ...companions.map((companion) {
                      final selected = selectedCompanions.contains(
                        companion.name,
                      );

                      final disabled = companion.name == '혼자'
                          ? _hasOtherCompanionSelected
                          : _isSoloSelected;

                      return _CompanionCard(
                        companion: companion,
                        selected: selected,
                        disabled: disabled,
                        onTap: () => _toggleCompanion(companion.name),
                      );
                    }),

                    const SizedBox(height: 22),

                    Text(
                      '여행자 연령대',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isSoloSelected
                          ? '혼자 여행은 아동을 제외한 연령대 1개만 선택할 수 있습니다.'
                          : '해당하는 연령대를 선택해주세요. 동행자가 있으면 여러 항목을 선택할 수 있으며 선택하지 않아도 됩니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 18),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ageGroups.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.55,
                          ),
                      itemBuilder: (context, index) {
                        final ageGroup = ageGroups[index];
                        final selected = selectedAgeGroups.contains(
                          ageGroup.name,
                        );

                        return _AgeGroupCard(
                          ageGroup: ageGroup,
                          disabled: _isSoloSelected && ageGroup.name == '아동',
                          selected: selected,
                          onTap: () => _toggleAgeGroup(ageGroup.name),
                        );
                      },
                    ),

                    if (selectedAgeGroups.isNotEmpty) ...[
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '선택한 연령대: ${selectedAgeGroups.join(', ')}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            TripBottomNavigation(
              onPrevious: () => context.go(AppRoutes.tripFixedSchedule),
              onNext: _goNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final _CompanionItem companion;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _CompanionCard({
    required this.companion,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : disabled
        ? AppColors.textSecondary.withOpacity(0.45)
        : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: disabled && !selected
            ? AppColors.border.withOpacity(0.25)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : disabled
                    ? AppColors.border.withOpacity(0.6)
                    : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                if (!disabled || selected)
                  BoxShadow(
                    color: selected
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.black.withOpacity(0.04),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(companion.icon, color: color, size: 30),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companion.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? AppColors.primary
                              : disabled
                              ? AppColors.textSecondary.withOpacity(0.55)
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        companion.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: disabled && !selected
                              ? AppColors.textSecondary.withOpacity(0.55)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                if (selected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  )
                else if (disabled)
                  Icon(
                    Icons.block_rounded,
                    color: AppColors.textSecondary.withOpacity(0.45),
                  )
                else
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeGroupCard extends StatelessWidget {
  final _AgeGroupItem ageGroup;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _AgeGroupCard({
    required this.ageGroup,
    required this.selected,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? AppColors.textSecondary.withValues(alpha: 0.4)
        : selected
        ? AppColors.primary
        : AppColors.textSecondary;

    return Material(
      color: disabled ? AppColors.border.withValues(alpha: 0.3) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primary.withOpacity(0.10)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ageGroup.icon, color: color, size: 22),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ageGroup.name,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ageGroup.range,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanionItem {
  final String name;
  final String description;
  final IconData icon;

  const _CompanionItem({
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _AgeGroupItem {
  final String name;
  final String range;
  final IconData icon;

  const _AgeGroupItem({
    required this.name,
    required this.range,
    required this.icon,
  });
}
