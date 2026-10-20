import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_page_header.dart';

class InformationPage extends StatelessWidget {
  const InformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const AppDrawer(currentRoute: AppRoutes.information),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: '정보 서비스',
                    onMenuTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),

                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.info_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '일본 여행 전 꼭 알아두면 좋은 실용 정보를 한곳에서 확인하세요.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _InfoTile(
                    icon: Icons.travel_explore_rounded,
                    title: '여행 정보',
                    description: '입국, 통신, 준비물 등 기본 여행 정보',
                    items: [
                      '여권 유효기간을 미리 확인하세요.',
                      '일본은 단기 관광 시 비자가 면제되는 경우가 많습니다.',
                      '현지 인터넷 사용을 위해 유심, eSIM, 포켓 Wi-Fi를 준비하세요.',
                      '여행 전 숙소 주소와 비상 연락처를 따로 저장해두면 좋습니다.',
                    ],
                  ),

                  const _InfoTile(
                    icon: Icons.volunteer_activism_rounded,
                    title: '에티켓 및 문화',
                    description: '식당, 대중교통, 온천 등 일본 문화 안내',
                    items: [
                      '대중교통에서는 통화를 자제하는 것이 좋습니다.',
                      '식당에서는 큰 소리로 대화하지 않는 편이 좋습니다.',
                      '온천 이용 전에는 반드시 몸을 씻고 들어갑니다.',
                      '길거리 쓰레기통이 적으므로 작은 봉투를 챙기면 편리합니다.',
                    ],
                  ),

                  const _InfoTile(
                    icon: Icons.directions_train_rounded,
                    title: '교통수단',
                    description: '대중교통, 교통패스, 국제운전면허 안내',
                    items: [
                      '도시 이동은 지하철과 JR 노선을 함께 확인하세요.',
                      '여행 일정에 따라 교통패스가 더 저렴할 수 있습니다.',
                      '차량 렌트를 하려면 국제운전면허증을 준비해야 합니다.',
                      '일본은 좌측통행이므로 운전 시 주의가 필요합니다.',
                    ],
                  ),

                  const _InfoTile(
                    icon: Icons.payments_rounded,
                    title: '결제 및 화폐',
                    description: '엔화, 카드, ATM, 환전 관련 정보',
                    items: [
                      '일본은 아직 현금 사용이 많은 곳이 있습니다.',
                      '편의점 ATM에서 해외 카드 출금이 가능한 경우가 많습니다.',
                      '카드 결제가 안 되는 소규모 가게를 대비해 현금을 준비하세요.',
                      '환율은 출국 전과 현지 ATM 수수료를 비교해보는 것이 좋습니다.',
                    ],
                  ),

                  const _InfoTile(
                    icon: Icons.health_and_safety_rounded,
                    title: '안전 및 보건',
                    description: '응급상황, 병원, 약국 이용 안내',
                    items: [
                      '응급상황 시 일본의 구급·소방 번호는 119입니다.',
                      '경찰 신고는 110입니다.',
                      '해외여행자 보험 가입 여부를 미리 확인하세요.',
                      '복용 중인 약이 있다면 영문 처방 정보나 약 이름을 준비하세요.',
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '버스 정류장: 국토수치정보(일본 국토교통성), 2022년 자료 · CC BY 4.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const _InfoTile(
                    icon: Icons.flight_takeoff_rounded,
                    title: '공항 이용 팁',
                    description: '입국, 세관, 수하물, 공항 이동 팁',
                    items: [
                      '입국 심사에 필요한 숙소 주소를 미리 준비하세요.',
                      '수하물 규정과 기내 반입 금지 물품을 확인하세요.',
                      '공항에서 시내로 이동하는 교통편을 미리 확인하면 좋습니다.',
                      '귀국 전 면세품과 세관 신고 기준을 확인하세요.',
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> items;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
          children: [
            Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    height: 1.45,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
