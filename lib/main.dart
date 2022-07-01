import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:budgetme/src/config/constants.dart';
import 'package:budgetme/src/config/themes/dark_theme/dark_theme.dart';
import 'package:budgetme/src/config/themes/light_theme/light_theme.dart';
import 'package:budgetme/src/providers/balance_repository_provider.dart';
import 'package:budgetme/src/providers/goal_repository_provider.dart';
import 'package:budgetme/src/providers/notification_service_provider.dart';
import 'package:budgetme/src/providers/theme_provider.dart';
import 'package:budgetme/src/services/notification_service.dart';
import 'package:budgetme/src/ui/views/all_goals_view/all_goals_view.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();

    await Hive.initFlutter();
    await Hive.openBox('budgetme');

    if (kDebugMode) {
      // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    final localDir = await getApplicationDocumentsDirectory();
    generalGoalImagePath = localDir.path;

    runApp(
      DevicePreview(
        enabled: false,
        tools: const [...DevicePreview.defaultTools, DevicePreviewScreenshot()],
        builder: (context) => const ProviderScope(child: BudgetMe()),
      ),
    );
  }, (error, stack) async {
    await FirebaseCrashlytics.instance.recordError(error, stack);
  });
}

class BudgetMe extends ConsumerStatefulWidget {
  const BudgetMe({Key? key}) : super(key: key);

  @override
  ConsumerState<BudgetMe> createState() => _BudgetMeState();
}

class _BudgetMeState extends ConsumerState<BudgetMe> {
  @override
  void initState() {
    super.initState();
    _loadData();
    _startNotifications();
  }

  void _loadData() {
    ref.read(goalRepositoryProvider.notifier).loadData();
    ref.read(balanceRepositoryProvider).loadData();
  }

  void _startNotifications() async {
    await NotificationService.init(initScheduled: true);
    await ref.read(notificationServiceProvider).showScheduledNotification();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(428, 926),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context) {
        final repo = ref.watch(themeProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: kAppTitle,
          themeMode: repo.themeMode,
          theme: lightTheme(),
          darkTheme: darkTheme(),
          home: const AllGoalsView(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [
            Locale('en', ''),
            Locale('es', ''),
          ],
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                child: Navigator(
                  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (context) {
                        return child!;
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
