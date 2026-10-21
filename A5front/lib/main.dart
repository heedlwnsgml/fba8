import 'core/widgets/weather_notifications.dart';
import 'core/state/trip_draft.dart';
import 'core/network/planner_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/generation_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TripDraft.instance.loadDefaults();
  await PlannerApi.instance.restoreWeatherSession();
  runApp(const ProviderScope(child: AITravelPlannerApp()));
}

class AITravelPlannerApp extends StatelessWidget {
  const AITravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Travel Planner',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) =>
          WeatherNotifications(child: GenerationNotifications(child: child!)),
    );
  }
}
