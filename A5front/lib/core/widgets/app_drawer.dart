import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../network/planner_api.dart';
import '../theme/app_colors.dart';
import 'app_confirm_dialog.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final result = await showAppConfirmDialog(
      context: context,
      title: '로그아웃하시겠습니까?',
      message: '현재 계정에서 로그아웃됩니다.',
      confirmText: '로그아웃',
    );

    if (result) {
      PlannerApi.instance.logout();
      if (navigator.canPop()) {
        navigator.pop();
      }

      router.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI Travel Planner',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                '스마트 일본 여행 도우미',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 28),

              _DrawerItem(
                icon: Icons.person_rounded,
                label: '마이페이지',
                route: AppRoutes.mypage,
                currentRoute: currentRoute,
              ),
              _DrawerItem(
                icon: Icons.home_rounded,
                label: '홈',
                route: AppRoutes.home,
                currentRoute: currentRoute,
              ),
              _DrawerItem(
                icon: Icons.add_circle_rounded,
                label: '일정 생성',
                route: AppRoutes.tripPeriod,
                currentRoute: currentRoute,
              ),
              _DrawerItem(
                icon: Icons.event_note_rounded,
                label: '일정 조회',
                route: AppRoutes.schedule,
                currentRoute: currentRoute,
              ),
              _DrawerItem(
                icon: Icons.info_rounded,
                label: '정보 서비스',
                route: AppRoutes.information,
                currentRoute: currentRoute,
              ),
              _DrawerItem(
                icon: Icons.local_hospital_rounded,
                label: '긴급 시설 위치 안내',
                route: AppRoutes.emergency,
                currentRoute: currentRoute,
                color: AppColors.emergency,
              ),

              const Spacer(),

              _LogoutButton(onTap: () => _showLogoutDialog(context)),

              const SizedBox(height: 14),

              Text(
                'Version 1.0',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selected = route == currentRoute;
    final itemColor =
        color ?? (selected ? AppColors.primary : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? itemColor.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();

            if (!selected) {
              context.go(route);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: itemColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: itemColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: AppColors.textSecondary,
                size: 23,
              ),
              SizedBox(width: 12),
              Text(
                '로그아웃',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
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
