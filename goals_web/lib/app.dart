import 'dart:async' show StreamSubscription, Timer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, MaterialApp, MaterialPageRoute, Scaffold;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        ConnectionState,
        FutureBuilder,
        Locale,
        Navigator,
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
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_context.dart';
import 'goal_viewer/goal_viewer.dart';
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

  Future<void> appInit(context) async {
    await this.syncClient.init();
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      this.ref.read(worldContextProvider.notifier).poke();
    });
    stateSubscription = this
        .syncClient
        .stateSubject
        .asBroadcastStream()
        .listen((Map<String, Goal> goalMap) {
      this.ref.read(worldContextProvider.notifier).poke();
    });
    if (FirebaseAuth.instance.currentUser == null &&
        this.widget.shouldAuthenticate) {
      Navigator.pushReplacementNamed(context, '/sign-in');
    }
    this.ref.read(debugProvider.notifier).set(this.widget.debug);
  }

  @override
  void dispose() {
    this.refreshTimer.cancel();
    this.stateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppContext(
      syncClient: syncClient,
      child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en', 'GB'),
          ],
          initialRoute: '/home',
          theme: theme,
          onGenerateRoute: (settings) {
            if (settings.name != null &&
                settings.name!.startsWith('/sign-in')) {
              return MaterialPageRoute(
                  builder: (context) => SignInScreen(
                        actions: [
                          AuthStateChangeAction<SignedIn>((context, state) {
                            Navigator.pushReplacementNamed(context, '/home');
                          })
                        ],
                      ));
            } else if (settings.name != null &&
                settings.name!.startsWith('/home')) {
              return MaterialPageRoute(
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
                      }));
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
