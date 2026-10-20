import '../../../core/widgets/app_dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../services/permission_service.dart';
import '../widgets/latest_trip_preview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool isLocationPermissionLoading = true;
  bool locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocationPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocationPermissionStatus();
    }
  }

  Future<void> _loadLocationPermissionStatus() async {
    final locationGranted = await PermissionService.isLocationGranted();

    if (!mounted) return;

    setState(() {
      locationPermissionGranted = locationGranted;
      isLocationPermissionLoading = false;
    });
  }

  Future<void> _startTrip() async {
    final controller = TextEditingController(text: TripDraft.instance.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 일정 이름'),
        content: TextField(
          controller: controller,
          maxLength: 100,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '미입력 시 첫 도시 ~ 마지막 도시 여행',
            labelText: '일정 이름 (선택)',
          ),
        ),
        actions: [
          AppDialogActions(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('다음'),
              ),
            ],
          ),
        ],
      ),
    );
    // Dialog exit animation still reads its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || title == null) return;
    TripDraft.instance.title = title;
    context.go(AppRoutes.tripPeriod);
  }

  void _goEmergencyPage() {
    context.go(AppRoutes.emergency);
  }

  @override
  Widget build(BuildContext context) {
    const emergencyDisabled = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const AppDrawer(currentRoute: AppRoutes.home),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    onMenuTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),

                  const SizedBox(height: 28),

                  _CreateTripCard(onTap: _startTrip),

                  const SizedBox(height: 26),

                  _SectionHeader(
                    title: '내 여행 일정',
                    actionText: '전체보기',
                    onActionTap: () => context.go(AppRoutes.schedule),
                  ),

                  const SizedBox(height: 12),

                  const LatestTripPreview(),

                  const SizedBox(height: 26),

                  Text(
                    '여행 도우미',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.info_outline_rounded,
                          title: '정보 서비스',
                          description: '일본 여행에 필요한 정보를 확인하세요.',
                          onTap: () => context.go(AppRoutes.information),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.local_hospital_rounded,
                          title: '긴급 시설',
                          description: '',
                          onTap: _goEmergencyPage,
                          isEmergency: true,
                          isDisabled: emergencyDisabled,
                          isLoading: false,
                        ),
                      ),
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

class _HomeHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _HomeHeader({required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘은 어떤 여행을\n계획해볼까요?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ],
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

class _CreateTripCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTripCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '일정 생성',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '여행 기간과 도시, 테마를 선택하면 이동 경로와 교통비를 포함한 일정을 만들어 드려요.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          child: Text(
            actionText,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isEmergency;
  final bool isDisabled;
  final bool isLoading;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isEmergency = false,
    this.isDisabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEmergency ? AppColors.emergency : AppColors.primary;
    final effectiveColor = isDisabled ? AppColors.textSecondary : color;

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: effectiveColor, size: 30),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDisabled
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.35,
                    color: isDisabled
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
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
