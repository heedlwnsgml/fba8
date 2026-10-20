import '../network/planner_api.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/system_back_page.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/email_login_page.dart';
import '../../core/state/trip_draft.dart';
import '../../features/auth/pages/permission_page.dart';
import '../../features/emergency/pages/emergency_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/information/pages/information_page.dart';
import '../../features/mypage/pages/mypage_page.dart';
import '../../features/schedule/pages/itinerary_result_page.dart';
import '../../features/schedule/pages/saved_plans_page.dart';
import '../../features/splash/pages/splash_page.dart';
import '../../features/trip/pages/trip_accommodation_page.dart';
import '../../features/trip/pages/trip_preferences_page.dart';
import '../../features/trip/pages/trip_entry_exit_page.dart';
import '../../features/trip/pages/trip_fixed_schedule_page.dart';
import '../../features/trip/pages/trip_loading_page.dart';
import '../../features/trip/pages/trip_period_page.dart';
import '../../features/trip/pages/trip_region_page.dart';

final generationNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = createAppRouter();

GoRouter createAppRouter({PlannerApi? api}) {
  final auth = api ?? PlannerApi.instance;
  final router = GoRouter(
    navigatorKey: generationNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      const public = {
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.emailLogin,
        AppRoutes.integration,
        AppRoutes.permission,
      };
      return !auth.isLoggedIn && !public.contains(state.uri.path)
          ? AppRoutes.login
          : null;
    },
    routes: [
      _appRoute(
        path: AppRoutes.emailLogin,
        builder: (context, state) => const EmailLoginPage(),
      ),
      GoRoute(
        path: AppRoutes.integration,
        redirect: (context, state) => AppRoutes.emailLogin,
      ),
      _appRoute(
        path: AppRoutes.generated,
        builder: (context, state) {
          if (state.extra is! Map)
            return const Scaffold(body: Center(child: Text('저장된 일정을 선택하세요.')));
          final data = Map<String, dynamic>.from(state.extra as Map);
          final request = Map<String, dynamic>.from(data['request'] as Map);
          final response = Map<String, dynamic>.from(data['response'] as Map);
          return ItineraryResultPage(
            response: response,
            request: request,
            summary: ItinerarySummary.fromBackend(request, response),
          );
        },
      ),
      _appRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),

      _appRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),

      _appRoute(
        path: AppRoutes.permission,
        name: AppRouteNames.permission,
        builder: (context, state) => const PermissionPage(),
      ),

      _appRoute(
        path: AppRoutes.permissionSettings,
        name: AppRouteNames.permissionSettings,
        builder: (context, state) => const PermissionPage(isSettingsMode: true),
      ),

      _appRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomePage(),
      ),

      _appRoute(
        path: AppRoutes.mypage,
        name: AppRouteNames.mypage,
        builder: (context, state) => const MyPage(),
      ),

      _appRoute(
        path: AppRoutes.schedule,
        name: AppRouteNames.schedule,
        builder: (context, state) => SavedPlansPage(
          initialSelection: state.extra is int ? state.extra as int : null,
        ),
      ),

      _appRoute(
        path: AppRoutes.information,
        name: AppRouteNames.information,
        builder: (context, state) => const InformationPage(),
      ),

      _appRoute(
        path: AppRoutes.emergency,
        name: AppRouteNames.emergency,
        builder: (context, state) => const EmergencyPage(),
      ),

      // =========================================================
      // 여행 일정 생성 1 ~ 9단계
      // =========================================================
      _appRoute(
        path: AppRoutes.tripPeriod,
        name: AppRouteNames.tripPeriod,
        builder: (context, state) => const TripPeriodPage(),
      ),

      _appRoute(
        path: AppRoutes.tripRegion,
        name: AppRouteNames.tripRegion,
        builder: (context, state) => const TripRegionPage(),
      ),

      _appRoute(
        path: AppRoutes.tripEntryExit,
        name: AppRouteNames.tripEntryExit,
        builder: (context, state) => const TripEntryExitPage(),
      ),

      _appRoute(
        path: AppRoutes.tripAccommodation,
        name: AppRouteNames.tripAccommodation,
        builder: (context, state) =>
            TripAccommodationPage(travelPeriod: TripDraft.instance.period),
      ),

      _appRoute(
        path: AppRoutes.tripFixedSchedule,
        name: AppRouteNames.tripFixedSchedule,
        builder: (context, state) => const TripFixedSchedulePage(),
      ),

      _appRoute(
        path: AppRoutes.tripCompanion,
        name: AppRouteNames.tripCompanion,
        builder: (context, state) => const TripPreferencesPage(),
      ),

      _appRoute(
        path: AppRoutes.tripTheme,
        name: AppRouteNames.tripTheme,
        builder: (context, state) => const TripPreferencesPage(),
      ),

      _appRoute(
        path: AppRoutes.tripTransport,
        name: AppRouteNames.tripTransport,
        builder: (context, state) => const TripPreferencesPage(),
      ),

      _appRoute(
        path: AppRoutes.tripScheduleSettings,
        name: AppRouteNames.tripScheduleSettings,
        builder: (context, state) => const TripPreferencesPage(),
      ),

      // =========================================================
      // 일정 생성 및 결과
      // =========================================================
      _appRoute(
        path: AppRoutes.loading,
        name: AppRouteNames.loading,
        builder: (context, state) => const TripLoadingPage(),
      ),

      _appRoute(
        path: AppRoutes.result,
        name: AppRouteNames.result,
        builder: (context, state) {
          final extra = state.extra;

          return ItineraryResultPage(
            summary: extra == null ? null : ItinerarySummary.fromExtra(extra),
          );
        },
      ),
    ],
  );

  String? previousPath;
  router.routerDelegate.addListener(() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    TripDraft.instance.handleRouteChange(previousPath, path);
    previousPath = path;
  });
  return router;
}

GoRoute _appRoute({
  required String path,
  String? name,
  required Widget Function(BuildContext, GoRouterState) builder,
}) => GoRoute(
  path: path,
  name: name,
  builder: (context, state) {
    final page = builder(context, state);
    // These pages already handle generation and result-saving back actions.
    if (path == AppRoutes.loading ||
        path == AppRoutes.result ||
        path == AppRoutes.generated)
      return page;
    final previous = <String, String>{
      AppRoutes.emailLogin: AppRoutes.login,
      AppRoutes.integration: AppRoutes.emailLogin,
      AppRoutes.permission: AppRoutes.login,
      AppRoutes.permissionSettings: AppRoutes.mypage,
      AppRoutes.mypage: AppRoutes.home,
      AppRoutes.schedule: AppRoutes.home,
      AppRoutes.information: AppRoutes.home,
      AppRoutes.emergency: AppRoutes.home,
      AppRoutes.tripPeriod: AppRoutes.home,
      AppRoutes.tripRegion: AppRoutes.tripPeriod,
      AppRoutes.tripEntryExit: AppRoutes.tripRegion,
      AppRoutes.tripAccommodation: AppRoutes.tripEntryExit,
      AppRoutes.tripFixedSchedule: AppRoutes.tripAccommodation,
      AppRoutes.tripCompanion: AppRoutes.tripFixedSchedule,
      AppRoutes.tripTheme: AppRoutes.tripCompanion,
      AppRoutes.tripTransport: AppRoutes.tripTheme,
      AppRoutes.tripScheduleSettings: AppRoutes.tripTransport,
    }[path];
    return SystemBackPage(backRoute: previous, child: page);
  },
);

class AppRoutes {
  static const splash = '/';

  static const login = '/login';
  static const emailLogin = '/email-login';
  static const integration = '/integration';
  static const generated = '/generated';
  static const permission = '/permission';
  static const permissionSettings = '/permission-settings';

  static const home = '/home';
  static const mypage = '/mypage';
  static const schedule = '/schedule';
  static const information = '/information';
  static const emergency = '/emergency';

  // 여행 일정 생성
  static const tripPeriod = '/trip/period';
  static const tripRegion = '/trip/region';
  static const tripEntryExit = '/trip/entry-exit';
  static const tripAccommodation = '/trip/accommodation';
  static const tripFixedSchedule = '/trip/fixed-schedule';
  static const tripCompanion = '/trip/companion';
  static const tripTheme = '/trip/theme';
  static const tripTransport = '/trip/transport';
  static const tripScheduleSettings = '/trip/schedule-settings';

  static const loading = '/loading';
  static const result = '/result';
}

class AppRouteNames {
  static const splash = 'splash';

  static const login = 'login';
  static const permission = 'permission';
  static const permissionSettings = 'permissionSettings';

  static const home = 'home';
  static const mypage = 'mypage';
  static const schedule = 'schedule';
  static const information = 'information';
  static const emergency = 'emergency';

  // 여행 일정 생성
  static const tripPeriod = 'tripPeriod';
  static const tripRegion = 'tripRegion';
  static const tripEntryExit = 'tripEntryExit';
  static const tripAccommodation = 'tripAccommodation';
  static const tripFixedSchedule = 'tripFixedSchedule';
  static const tripCompanion = 'tripCompanion';
  static const tripTheme = 'tripTheme';
  static const tripTransport = 'tripTransport';
  static const tripScheduleSettings = 'tripScheduleSettings';

  static const loading = 'loading';
  static const result = 'result';
}
