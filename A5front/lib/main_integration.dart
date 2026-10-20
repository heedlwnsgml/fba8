import 'core/router/app_router.dart';
import 'main.dart' as app;

void main() {
  appRouter.go(AppRoutes.integration);
  app.main();
}
