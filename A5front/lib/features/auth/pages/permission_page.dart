import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/permission_service.dart';
import '../../../services/permission_onboarding.dart';
import '../../../core/network/planner_api.dart';

class PermissionPage extends StatefulWidget {
  final bool isSettingsMode;

  const PermissionPage({super.key, this.isSettingsMode = false});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool isLoading = true;
  Timer? _noticeTimer;
  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  bool locationPermission = false;
  bool notificationPermission = false;

  bool get isSettingsMode => widget.isSettingsMode;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final locationGranted = await PermissionService.isLocationGranted();
    final notificationGranted = await PermissionService.isNotificationGranted();

    if (!mounted) return;

    setState(() {
      locationPermission = locationGranted;
      notificationPermission = notificationGranted;
      isLoading = false;
    });
  }

  Future<void> _requestLocationPermission() async {
    if (locationPermission) {
      _showOpenSettingsSnackBar(
        '위치 권한이 이미 허용되어 있습니다. 권한을 끄려면 휴대폰 앱 설정에서 변경해주세요.',
      );
      return;
    }

    final status = await PermissionService.requestLocationPermission();
    final isGranted = status == PermissionStatus.granted;
    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

    if (!mounted) return;

    setState(() {
      locationPermission = isGranted;
    });

    if (isPermanentlyDenied) {
      _showOpenSettingsSnackBar('위치 권한이 차단되어 있습니다. 앱 설정에서 권한을 허용해주세요.');
    } else if (!isGranted) {
      _showSnackBar('위치 권한이 허용되지 않았습니다.');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (notificationPermission) {
      _showOpenSettingsSnackBar(
        '알림 권한이 이미 허용되어 있습니다. 권한을 끄려면 휴대폰 앱 설정에서 변경해주세요.',
      );
      return;
    }

    final status = await PermissionService.requestNotificationPermission();
    final isGranted = status == PermissionStatus.granted;
    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

    if (!mounted) return;

    setState(() {
      notificationPermission = isGranted;
    });

    if (isPermanentlyDenied) {
      _showOpenSettingsSnackBar('알림 권한이 차단되어 있습니다. 앱 설정에서 권한을 허용해주세요.');
    } else if (!isGranted) {
      _showSnackBar('알림 권한이 허용되지 않았습니다.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOpenSettingsSnackBar(String message) {
    _noticeTimer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(message),
        action: SnackBarAction(
          label: '설정',
          onPressed: () {
            PermissionService.openAppPermissionSettings();
          },
        ),
      ),
    );
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) messenger.hideCurrentSnackBar();
    });
  }

  void _handleBack() {
    context.go(AppRoutes.mypage);
  }

  bool _requestingPermissions = false;
  Future<void> _handleComplete() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    try {
      if (!locationPermission) await _requestLocationPermission();
      if (!mounted) return;
      if (!notificationPermission) await _requestNotificationPermission();
      if (!mounted) return;
      await _finishOnboarding();
    } finally {
      if (mounted) setState(() => _requestingPermissions = false);
    }
  }

  Future<void> _finishOnboarding() async {
    await PermissionOnboarding.complete();
    if (!mounted) return;
    context.go(
      PlannerApi.instance.isLoggedIn ? AppRoutes.home : AppRoutes.login,
    );
  }

  String get _title {
    if (isSettingsMode) {
      return '권한 설정';
    }

    return '여행 준비를\n시작해볼까요?';
  }

  String get _description {
    if (isSettingsMode) {
      return '앱 기능 사용을 위해 필요한 권한을 확인하고 설정할 수 있습니다.';
    }

    return '더 정확한 AI 여행 일정을 위해\n아래 권한을 허용해주세요.';
  }

  List<String> get _noticeItems {
    if (isSettingsMode) {
      return const [
        '권한을 허용하면 더 정확한 여행 정보와 알림을 받을 수 있습니다.',
        '권한을 끄려면 휴대폰 앱 설정에서 직접 변경해야 합니다.',
      ];
    }

    return const [
      '권한을 허용하면 더 정확한 여행 정보와 알림을 받을 수 있습니다.',
      '권한을 끄려면 휴대폰 앱 설정에서 직접 변경해야 합니다.',
      '지금 허용하지 않아도 나중에 마이페이지에서 다시 변경할 수 있습니다.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              if (isSettingsMode) ...[
                _BackButtonCard(onTap: _handleBack),
                const SizedBox(height: 18),
              ],

              Text(
                _title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                _description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 34),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _PermissionSettingCard(
                  icon: Icons.my_location_rounded,
                  title: '위치 권한 설정',
                  description: '현재 위치를 기반으로 주변 긴급 시설과 여행 정보를 제공합니다.',
                  isGranted: locationPermission,
                  onTap: _requestLocationPermission,
                ),

                const SizedBox(height: 16),

                _PermissionSettingCard(
                  icon: Icons.notifications_active_rounded,
                  title: '알림 권한 설정',
                  description: '날씨 변화와 일정 변경 등 중요한 정보를 알려드립니다.',
                  isGranted: notificationPermission,
                  onTap: _requestNotificationPermission,
                ),

                const SizedBox(height: 18),

                _PermissionNoticeBox(items: _noticeItems),

                const SizedBox(height: 28),

                if (!isSettingsMode) ...[
                  FilledButton(
                    onPressed: _requestingPermissions ? null : _handleComplete,
                    child: Text(_requestingPermissions ? '권한 확인 중' : '다음'),
                  ),
                  TextButton(
                    onPressed: _requestingPermissions
                        ? null
                        : _finishOnboarding,
                    child: const Text('나중에 설정'),
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButtonCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButtonCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PermissionSettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionSettingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isGranted ? '허용됨' : '허용 필요';
    final statusColor = isGranted ? AppColors.success : AppColors.textSecondary;
    final iconBackgroundColor = isGranted
        ? AppColors.success.withOpacity(0.12)
        : AppColors.primary.withOpacity(0.12);
    final iconColor = isGranted ? AppColors.success : AppColors.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionNoticeBox extends StatelessWidget {
  final List<String> items;

  const _PermissionNoticeBox({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '안내',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _NoticeItem(text: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  final String text;

  const _NoticeItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.primary,
            size: 14,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
