import '../../../core/widgets/app_dialog_actions.dart';
import '../widgets/exchange_rate_editor.dart';
import '../widgets/long_trip_settings_card.dart';
import '../widgets/hotel_currency_preference_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../services/permission_service.dart';
import '../../../core/network/planner_api.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, this.api});
  final PlannerApi? api;

  @override
  State<MyPage> createState() => _MyPageState();
}

enum NotificationFrequency { morning, afternoon, both }

class _MyPageState extends State<MyPage> with WidgetsBindingObserver {
  late final PlannerApi api;
  Map<String, dynamic>? profile;
  String? profileError;
  bool accountBusy = false;
  int profileLoad = 0;
  int? _weatherSession;
  Future<void> _weatherSaves = Future.value();
  bool isPermissionLoading = true;
  bool notificationPermissionGranted = false;

  bool weatherNotificationEnabled = true;
  NotificationFrequency notificationFrequency = NotificationFrequency.both;

  TimeOfDay morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay afternoonTime = const TimeOfDay(hour: 18, minute: 0);

  bool get canUseWeatherNotification =>
      notificationPermissionGranted && weatherNotificationEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissionStatus();
    api = widget.api ?? PlannerApi.instance;
    api.addListener(_loadProfile);
    _loadProfile();
    _loadWeather();
  }

  @override
  void dispose() {
    api.removeListener(_loadProfile);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPermissionStatus();
    }
  }

  Future<void> _loadPermissionStatus() async {
    bool notificationGranted = false;
    try {
      notificationGranted = await PermissionService.isNotificationGranted();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      notificationPermissionGranted = notificationGranted;
      isPermissionLoading = false;
    });
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final initialTime = isMorning ? morningTime : afternoonTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: isMorning ? '오전 알림 시간 선택' : '오후 알림 시간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (picked == null) return;

    setState(() {
      if (isMorning) {
        morningTime = picked;
      } else {
        afternoonTime = picked;
      }
    });
    _saveWeather();
  }

  String _formatTime(TimeOfDay time) {
    final isAm = time.hour < 12;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '${isAm ? '오전' : '오후'} $hour:$minute';
  }

  Future<void> _showLogoutDialog() async {
    final result = await showAppConfirmDialog(
      context: context,
      title: '로그아웃하시겠습니까?',
      message: '현재 계정에서 로그아웃됩니다.',
      confirmText: '로그아웃',
    );

    if (result && mounted) {
      api.logout();
      context.go(AppRoutes.login);
    }
  }

  Future<void> _showWithdrawDialog() async {
    if (accountBusy) return;
    final result = await showAppConfirmDialog(
      context: context,
      title: '회원탈퇴하시겠습니까?',
      message: '회원 정보와 저장된 여행 일정이 모두 삭제되며 복구할 수 없습니다.',
      confirmText: '회원탈퇴',
      type: AppConfirmDialogType.danger,
    );
    if (!result || !mounted) return;
    setState(() => accountBusy = true);
    try {
      await api.withdraw();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('탈퇴하지 못했습니다. $e')));
    } finally {
      if (mounted) setState(() => accountBusy = false);
    }
  }

  Future<void> _loadWeather() async {
    if (!api.isLoggedIn || _weatherSession == api.sessionRevision) return;
    final revision = api.sessionRevision;
    _weatherSession = revision;
    try {
      final settings = await api.getWeatherSettings();
      if (!mounted || revision != api.sessionRevision) return;
      TimeOfDay parse(dynamic value, TimeOfDay fallback) {
        final parts = value?.toString().split(':');
        if (parts == null || parts.length < 2) return fallback;
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      setState(() {
        weatherNotificationEnabled = settings['enabled'] == true;
        notificationFrequency = NotificationFrequency.values.firstWhere(
          (v) => v.name == settings['frequency'],
          orElse: () => NotificationFrequency.both,
        );
        morningTime = parse(settings['morningTime'], morningTime);
        afternoonTime = parse(settings['afternoonTime'], afternoonTime);
      });
    } catch (_) {
      _weatherSession = null;
    }
  }

  void _saveWeather() {
    if (!api.isLoggedIn) return;
    final revision = api.sessionRevision;
    String format(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final settings = {
      'enabled': weatherNotificationEnabled,
      'frequency': notificationFrequency.name,
      'morningTime': format(morningTime),
      'afternoonTime': format(afternoonTime),
    };
    _weatherSaves = _weatherSaves
        .then((_) async {
          if (api.isLoggedIn && api.sessionRevision == revision)
            await api.updateWeatherSettings(settings);
        })
        .catchError((Object error) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('날씨 알림 설정을 저장하지 못했습니다. 다시 선택해 주세요.'),
              ),
            );
        });
  }

  Future<void> _loadProfile() async {
    _loadWeather();
    final id = ++profileLoad, revision = api.sessionRevision;
    setState(() {
      profile = null;
      profileError = null;
    });
    if (!api.isLoggedIn) return;
    try {
      final value = await api.getProfile();
      if (mounted && id == profileLoad && revision == api.sessionRevision)
        setState(() => profile = value);
    } catch (e) {
      if (mounted && id == profileLoad && revision == api.sessionRevision)
        setState(() => profileError = e.toString());
    }
  }

  Future<void> _rename() async {
    if (accountBusy || profile == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditNameDialog(initial: profile?['displayName']?.toString() ?? ''),
    );
    if (name == null || !mounted) return;
    setState(() => accountBusy = true);
    try {
      final saved = await api.updateName(name);
      if (mounted) setState(() => profile = saved);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => accountBusy = false);
    }
  }

  void _goPermissionSettings() {
    context.go(AppRoutes.permissionSettings);
  }

  void _showNeedNotificationPermissionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기상 정보 알림을 사용하려면 알림 권한이 필요합니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationSectionOpacity = canUseWeatherNotification ? 1.0 : 0.45;

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const AppDrawer(currentRoute: AppRoutes.mypage),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: '마이페이지',
                    onMenuTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),

                  const SizedBox(height: 28),

                  _ProfileCard(
                    name:
                        (profile?['displayName']
                                ?.toString()
                                .trim()
                                .isNotEmpty ??
                            false)
                        ? profile!['displayName'].toString()
                        : (api.isLoggedIn ? '여행자' : '로그인이 필요합니다.'),
                    email: profile?['email']?.toString() ?? '',
                    onEdit: !accountBusy && profile != null ? _rename : null,
                  ),
                  if (api.isLoggedIn)
                    HotelCurrencyPreferenceCard(
                      key: ValueKey(api.sessionRevision),
                      api: api,
                    ),
                  if (api.isLoggedIn)
                    LongTripSettingsCard(
                      key: ValueKey('long-trip-${api.sessionRevision}'),
                      api: api,
                    ),
                  if (api.isAdmin)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '화면 보기 설정',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('관리자로 보기'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('일반 사용자로 보기'),
                                ),
                              ],
                              selected: {api.viewAsUser},
                              onSelectionChanged: (v) =>
                                  setState(() => api.setViewAsUser(v.first)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (profile?['canEditExchangeRate'] == true &&
                      api.showAdminInformation)
                    ExchangeRateEditor(api: api),
                  if (profileError != null) ...[
                    Text(profileError!),
                    TextButton(
                      onPressed: _loadProfile,
                      child: const Text('회원 정보 다시 불러오기'),
                    ),
                  ],

                  const SizedBox(height: 18),

                  _PermissionMenuCard(onTap: _goPermissionSettings),

                  const SizedBox(height: 18),

                  _SectionCard(
                    title: '기상 정보 알림',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notificationPermissionGranted
                                    ? '예보가 있는 여행 시간대의 강수확률과 일정 변경 안내를 받습니다. 절전 모드에서는 알림이 지연될 수 있습니다.'
                                    : '알림 권한을 허용하면 날씨 변화와 여행 알림을 받을 수 있습니다.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            if (isPermissionLoading)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Switch(
                                value: weatherNotificationEnabled,
                                activeColor: AppColors.primary,
                                onChanged: notificationPermissionGranted
                                    ? (value) {
                                        setState(() {
                                          weatherNotificationEnabled = value;
                                          _saveWeather();
                                        });
                                      }
                                    : (_) {
                                        _showNeedNotificationPermissionMessage();
                                      },
                              ),
                          ],
                        ),

                        if (!notificationPermissionGranted) ...[
                          const SizedBox(height: 14),
                          _PermissionNoticeBox(
                            text: '알림 권한이 없어 기상 정보 알림 기능이 비활성화되어 있습니다.',
                            buttonText: '권한 설정',
                            onTap: _goPermissionSettings,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Opacity(
                    opacity: notificationSectionOpacity,
                    child: IgnorePointer(
                      ignoring: !canUseWeatherNotification,
                      child: _SectionCard(
                        title: '알림 수신',
                        child: Column(
                          children: [
                            _RadioTile(
                              label: '오전만',
                              selected:
                                  notificationFrequency ==
                                  NotificationFrequency.morning,
                              onTap: () {
                                setState(() {
                                  notificationFrequency =
                                      NotificationFrequency.morning;
                                  _saveWeather();
                                });
                              },
                            ),
                            _RadioTile(
                              label: '오후만',
                              selected:
                                  notificationFrequency ==
                                  NotificationFrequency.afternoon,
                              onTap: () {
                                setState(() {
                                  notificationFrequency =
                                      NotificationFrequency.afternoon;
                                  _saveWeather();
                                });
                              },
                            ),
                            _RadioTile(
                              label: '오전 + 오후',
                              selected:
                                  notificationFrequency ==
                                  NotificationFrequency.both,
                              onTap: () {
                                setState(() {
                                  notificationFrequency =
                                      NotificationFrequency.both;
                                  _saveWeather();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Opacity(
                    opacity: notificationSectionOpacity,
                    child: IgnorePointer(
                      ignoring: !canUseWeatherNotification,
                      child: _SectionCard(
                        title: '알림 시간',
                        child: Column(
                          children: [
                            if (notificationFrequency ==
                                    NotificationFrequency.morning ||
                                notificationFrequency ==
                                    NotificationFrequency.both)
                              _TimeTile(
                                label: '오전 시간',
                                time: _formatTime(morningTime),
                                onTap: () => _pickTime(isMorning: true),
                              ),
                            if (notificationFrequency ==
                                    NotificationFrequency.afternoon ||
                                notificationFrequency ==
                                    NotificationFrequency.both)
                              Padding(
                                padding: EdgeInsets.only(
                                  top:
                                      notificationFrequency ==
                                          NotificationFrequency.both
                                      ? 12
                                      : 0,
                                ),
                                child: _TimeTile(
                                  label: '오후 시간',
                                  time: _formatTime(afternoonTime),
                                  onTap: () => _pickTime(isMorning: false),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _showLogoutDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: accountBusy ? null : _showWithdrawDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        '회원탈퇴',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, this.onEdit});
  final String name, email;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '여행자' : name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(email, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: '이름 변경',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _PermissionMenuCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PermissionMenuCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.privacy_tip_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '권한 설정',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '위치 권한과 알림 권한을 확인하고 변경할 수 있습니다.',
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
  final String text;
  final String buttonText;
  final VoidCallback onTap;

  const _PermissionNoticeBox({
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withOpacity(0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});
  final String initial;
  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    if (form.currentState!.validate())
      Navigator.pop(context, controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('이름 변경'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(labelText: '이름'),
        validator: (value) =>
            value == null || value.trim().isEmpty ? '이름을 입력해주세요.' : null,
        onFieldSubmitted: (_) => save(),
      ),
    ),
    actions: [
      AppDialogActions(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(onPressed: save, child: const Text('저장')),
        ],
      ),
    ],
  );
}
