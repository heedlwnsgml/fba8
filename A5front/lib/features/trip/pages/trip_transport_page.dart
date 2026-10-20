import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/draft_autosave.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/trip_bottom_navigation.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_indicator.dart';

class TripTransportPage extends StatefulWidget {
  const TripTransportPage({super.key});

  @override
  State<TripTransportPage> createState() => _TripTransportPageState();
}

class _TripTransportPageState extends State<TripTransportPage>
    with DraftAutosave<TripTransportPage> {
  @override
  void saveDraft() {
    if (!canSaveDraft) return;
    final d = TripDraft.instance;
    d.transport = selectedTransport;
  }

  // =========================================================
  // 선택된 주요 이동수단
  //
  // 현재는 한 가지 이동수단만 선택할 수 있습니다.
  // 선택한 항목을 다시 누르면 선택을 해제할 수 있습니다.
  // =========================================================

  String? selectedTransport;

  // =========================================================
  // 이동수단 목록
  //
  // 1. 도보 및 대중교통
  // 2. 차량 렌트
  // =========================================================

  final List<_TransportItem> transports = const [
    _TransportItem(
      name: '도보 및 대중교통',
      description: '전철, 버스와 도보를 중심으로 이동합니다.',
      icon: Icons.directions_transit_rounded,
    ),
    _TransportItem(
      name: '차량 렌트',
      description: '렌터카를 이용한 이동을 중심으로 일정을 구성합니다.',
      icon: Icons.directions_car_filled_rounded,
    ),
  ];

  // =========================================================
  // 이동수단 선택 / 선택 해제
  //
  // 이미 선택된 이동수단을 다시 누르면 선택을 해제합니다.
  // 다른 이동수단을 누르면 선택 항목이 변경됩니다.
  // =========================================================

  void _toggleTransport(String transport) {
    setState(() {
      if (selectedTransport == transport) {
        selectedTransport = null;
      } else {
        selectedTransport = transport;
      }
    });
  }

  // =========================================================
  // 이전 단계
  //
  // 8단계 이동수단 → 7단계 여행 테마
  // =========================================================

  void _goPrevious() {
    context.go(AppRoutes.tripTheme);
  }

  // =========================================================
  // 다음 단계
  //
  // 이동수단을 하나 선택한 경우에만
  // 9단계 일정 설정 화면으로 이동합니다.
  //
  // 기존:
  // 이동수단 → 로딩
  //
  // 변경:
  // 이동수단 → 일정 설정 → 로딩
  // =========================================================

  void _goNext() {
    if (selectedTransport == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주요 이동수단을 선택해주세요.')));

      return;
    }

    context.go(AppRoutes.tripScheduleSettings);
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  void initState() {
    super.initState();
    final d = TripDraft.instance;
    selectedTransport = d.transport;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // 8단계 상단 헤더
            // =================================================

            const TripStepHeader(currentStep: 8),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TripStepIndicator(currentStep: 8),

                    const SizedBox(height: 34),

                    Text(
                      '주로 어떻게\n이동하시나요?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '여행 중 주로 이용할 이동수단을 선택하면 이동 방식에 맞춰 일정을 구성합니다.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =================================================
                    // 이동수단 선택 카드
                    // =================================================
                    Text(
                      '섬 간 이동',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final mode in ['비행기', '배'])
                          ChoiceChip(
                            label: Text(mode),
                            selected:
                                TripDraft.instance.interIslandTransport == mode,
                            onSelected: (_) => setState(
                              () => TripDraft.instance.interIslandTransport =
                                  mode,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...transports.map((transport) {
                      final selected = selectedTransport == transport.name;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TransportCard(
                          transport: transport,
                          selected: selected,
                          onTap: () {
                            _toggleTransport(transport.name);
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // =================================================
                    // 선택된 이동수단 안내
                    // =================================================
                    if (selectedTransport != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                '선택한 이동수단: $selectedTransport',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
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
            // 이전 → 여행 테마
            // 다음 → 일정 설정
            //
            // AI 일정 생성 버튼은 다음 9단계로 이동했습니다.
            // =================================================
            TripBottomNavigation(
              onPrevious: _goPrevious,
              onNext: _goNext,
              nextText: '다음',
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 이동수단 선택 카드
//
// 선택 상태에 따라
// 테두리, 아이콘, 체크 아이콘의 색상이 변경됩니다.
// ===========================================================

class _TransportCard extends StatelessWidget {
  final _TransportItem transport;
  final bool selected;
  final VoidCallback onTap;

  const _TransportCard({
    required this.transport,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // =============================================
              // 이동수단 아이콘
              // =============================================

              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(transport.icon, color: color, size: 31),
              ),

              const SizedBox(width: 16),

              // =============================================
              // 이동수단 이름 / 설명
              // =============================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transport.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      transport.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // =============================================
              // 선택 상태
              // =============================================
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 28,
                )
              else
                const Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 이동수단 데이터 모델
// ===========================================================

class _TransportItem {
  final String name;
  final String description;
  final IconData icon;

  const _TransportItem({
    required this.name,
    required this.description,
    required this.icon,
  });
}
