import 'dart:async' show StreamSubscription, Timer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, MaterialApp, Scaffold;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        ConnectionState,
        FutureBuilder,
        GlobalKey,
        Locale,
        NavigatorState,
        SingleTickerProviderStateMixin,
        SizedBox,
        StatelessWidget,
        StreamBuilder,
        Widget;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/widgets/unanimated_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_context.dart';
import 'goal_viewer/goal_viewer.dart';
import 'landing_page.dart';
import 'styles.dart';

class WebGoals extends ConsumerStatefulWidget {
  final bool shouldAuthenticate;
  final PersistenceService persistenceService;
  final bool debug;
  const WebGoals({
    super.key,
    this.shouldAuthenticate = true,
    required this.persistenceService,
    this.debug = false,
  });

  @override
  ConsumerState<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends ConsumerState<WebGoals>
    with SingleTickerProviderStateMixin {
  late SyncClient syncClient =
      SyncClient(persistenceService: this.widget.persistenceService);

  // responsible for updating the world state so the UI updates according with the current time
  late Timer refreshTimer;

  late StreamSubscription stateSubscription;
  late StreamSubscription userSubscription;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void initState() {
    super.initState();
    this.userSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && this.widget.shouldAuthenticate) {
        this.navigatorKey.currentState?.pushReplacementNamed('/');
      } else if (user != null) {
        this.navigatorKey.currentState?.pushReplacementNamed('/home');
      }
    });
  }

  Future<void> appInit(context) async {
    await this.syncClient.init();
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      worldContextStream.add(WorldContext.now());
    });
    stateSubscription = this
        .syncClient
        .stateSubject
        .asBroadcastStream()
        .listen((Map<String, Goal> goalMap) {
      worldContextStream.add(WorldContext.now());
    });
    this.ref.read(debugProvider.notifier).set(this.widget.debug);
  }

  @override
  void dispose() {
    this.refreshTimer.cancel();
    this.stateSubscription.cancel();
    this.userSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppContext(
      syncClient: syncClient,
      child: MaterialApp(
          navigatorKey: this.navigatorKey,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en', 'GB'),
          ],
          initialRoute:
              FirebaseAuth.instance.currentUser == null ? '/' : '/home',
          theme: theme,
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name == '/') {
              return UnanimatedPageRoute(
                  builder: (context) => LandingPage(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/register')) {
              return UnanimatedPageRoute(
                  builder: (context) => RegisterScreen(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/sign-in')) {
              return UnanimatedPageRoute(
                  builder: (context) => SignInScreen(), settings: settings);
            } else if (settings.name != null &&
                settings.name!.startsWith('/home')) {
              return UnanimatedPageRoute(
                  builder: (context) => FutureBuilder<void>(
                      future: appInit(context),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator()));
                        }
                        return GoalsHome();
                      }),
                  settings: settings);
            }
          }),
    );
  }
}

class GoalsHome extends StatelessWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, Goal>>(
          stream: AppContext.of(context).syncClient.stateSubject,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()));
            }
            return GoalViewer(goalMap: snapshot.requireData);
          }),
    );
  }
}
