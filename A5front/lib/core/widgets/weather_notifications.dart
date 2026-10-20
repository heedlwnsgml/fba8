import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../network/planner_api.dart';
import '../router/app_router.dart';
import 'app_confirm_dialog.dart';

class WeatherNotifications extends StatefulWidget {
  const WeatherNotifications({super.key, required this.child, this.api});
  final Widget child;
  final PlannerApi? api;
  @override
  State<WeatherNotifications> createState() => _WeatherNotificationsState();
}

class _WeatherNotificationsState extends State<WeatherNotifications>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('ai_travel_planner/weather');
  PlannerApi get api => widget.api ?? PlannerApi.instance;
  int _session = -1, _plans = -1, _weather = -1, _syncId = 0;
  int? _pendingPlan;
  bool _dialog = false;
  bool get native => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    api.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    if (native)
      channel.setMethodCallHandler((call) async {
        if (call.method == 'notificationTapped' && call.arguments is num) {
          _pendingPlan = (call.arguments as num).toInt();
          await _open();
        }
      });
    _changed();
  }

  @override
  void dispose() {
    api.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    if (native) channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    }
  }

  void _changed() {
    if (_session == api.sessionRevision &&
        _plans == api.plansRevision &&
        _weather == api.weatherRevision)
      return;
    _session = api.sessionRevision;
    _plans = api.plansRevision;
    _weather = api.weatherRevision;
    _sync();
  }

  Future<void> _sync() async {
    if (!native) return;
    final id = ++_syncId;
    try {
      final tapped = await channel.invokeMethod<int>('takeTappedPlan');
      if (tapped != null) _pendingPlan = tapped;
      if (!api.isLoggedIn) {
        await channel.invokeMethod('clear');
        return;
      }
      final settings = await api.getWeatherSettings();
      final alerts = await api.getWeatherAlerts();
      if (!mounted || id != _syncId) return;
      await channel.invokeMethod('configure', {
        ...settings,
        'baseUrl': api.baseUrl,
        'token': api.weatherSessionToken,
        'alerts': alerts,
      });
      await _open();
    } catch (_) {
      /* Leave the last valid schedule/cache when the server is unavailable. */
    }
  }

  Future<void> _open() async {
    if (_dialog || _pendingPlan == null || !api.isLoggedIn) return;
    final planId = _pendingPlan!;
    _pendingPlan = null;
    _dialog = true;
    try {
      final data = await api.getPlan(planId);
      if (!mounted) return;
      appRouter.go(AppRoutes.generated, extra: data);
      await WidgetsBinding.instance.endOfFrame;
      final root = appRouter.routerDelegate.navigatorKey.currentContext;
      if (root == null || !root.mounted) return;
      final approved = await showAppConfirmDialog(
        context: root,
        title: '날씨에 맞춰 일정을 변경할까요?',
        message: '예보가 있는 방문 시간대의 강수확률을 반영해 일정을 다시 구성합니다. 고정 일정은 유지됩니다.',
        confirmText: '일정 변경',
        cancelText: '유지',
      );
      if (approved && mounted) {
        await api.regeneratePlan(
          planId,
          Map<String, dynamic>.from(data['request'] as Map),
        );
        if (mounted)
          appRouter.go(AppRoutes.generated, extra: await api.getPlan(planId));
      }
    } catch (_) {
      final root = appRouter.routerDelegate.navigatorKey.currentContext;
      if (root != null && root.mounted)
        ScaffoldMessenger.of(root).showSnackBar(
          const SnackBar(
            content: Text("날씨에 따른 일정 변경을 완료하지 못했습니다. 다시 시도해 주세요."),
          ),
        );
    } finally {
      _dialog = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
