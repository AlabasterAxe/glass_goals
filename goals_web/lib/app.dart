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
        Locale,
        Navigator,
        SingleTickerProviderStateMixin,
        SizedBox,
        State,
        StatefulWidget,
        StatelessWidget,
        StreamBuilder,
        Widget;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations;
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';

import 'app_context.dart';
import 'goal_viewer/goal_viewer.dart';
import 'styles.dart';

class WebGoals extends StatefulWidget {
  final bool shouldAuthenticate;
  final PersistenceService persistenceService;
  const WebGoals({
    super.key,
    this.shouldAuthenticate = true,
    required this.persistenceService,
  });

  @override
  State<WebGoals> createState() => _WebGoalsState();
}

class _WebGoalsState extends State<WebGoals>
    with SingleTickerProviderStateMixin {
  late SyncClient syncClient =
      SyncClient(persistenceService: widget.persistenceService);

  Future<void> appInit(context) async {
    await syncClient.init();
    if (FirebaseAuth.instance.currentUser == null &&
        widget.shouldAuthenticate) {
      Navigator.pushReplacementNamed(context, '/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('en', 'GB'),
        ],
        initialRoute: '/home',
        theme: theme,
        routes: {
          '/sign-in': (context) => SignInScreen(
                actions: [
                  AuthStateChangeAction<SignedIn>((context, state) {
                    Navigator.pushReplacementNamed(context, '/home');
                  })
                ],
              ),
          '/home': (context) => FutureBuilder<void>(
              future: appInit(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator()));
                }
                return AppContext(
                    syncClient: syncClient, child: const GoalsHome());
              }),
        });
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
