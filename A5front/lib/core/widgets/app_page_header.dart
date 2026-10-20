import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onMenuTap;
  final String backRoute;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.onMenuTap,
    this.backRoute = AppRoutes.home,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => context.go(backRoute),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),

        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: const Icon(
                Icons.menu_rounded,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
