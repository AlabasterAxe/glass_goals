import 'dart:async';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goals_glass/sync/persistence_service.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart' show PublishSubject, Subject;
import 'package:screen_brightness/screen_brightness.dart' show ScreenBrightness;

import 'app_context.dart' show AppContext;
import 'settings/settings_widget.dart';
import 'styles.dart' show mainTextStyle;
import 'util/glass_gesture_detector.dart';
import 'util/glass_page_view.dart' show GlassPageView;
import 'util/glass_scaffold.dart';
import 'goal.dart' show GoalsWidget, GoalTitle;
import '../../model.dart' show Goal;
import 'stt_service.dart' show SttService;
import '../../sync/sync_client.dart' show SyncClient, rootGoal;

void main() {
  runApp(const GlassGoals());
}

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key});

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals>
    with SingleTickerProviderStateMixin {
  SttService sttService = SttService();
  SyncClient syncClient =
      SyncClient(persistenceService: GoogleSheetsPersistenceService());
  RestartableTimer screenOffTimer =
      RestartableTimer(const Duration(seconds: 10), () {
    ScreenBrightness().setScreenBrightness(0.0);
  });
  late AnimationController backgroundColorAnimationController =
      AnimationController(vsync: this);
  Subject interactionSubject = PublishSubject<void>();

  Future<void> appInit() async {
    await syncClient.init();
    Timer.periodic(const Duration(minutes: 10), (_) {
      final hintingEnabled = Hive.box('glass_goals.settings')
          .get('enableHinting', defaultValue: true);
      if (hintingEnabled) {
        ScreenBrightness().setScreenBrightness(1.0);
        screenOffTimer.reset();
        backgroundColorAnimationController.forward().then((_) {
          backgroundColorAnimationController.reverse();
        });
      }
    });
    backgroundColorAnimationController.value = 0.0;
    backgroundColorAnimationController.duration = const Duration(seconds: 10);
    interactionSubject.listen((_) {
      ScreenBrightness().setScreenBrightness(1.0);
      screenOffTimer.reset();
      backgroundColorAnimationController.animateBack(0.0,
          duration: const Duration(milliseconds: 300));
    });
    await Hive.openBox('glass_goals.settings');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: appInit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
                home: Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator()))));
          }
          return AppContext(
              sttService: sttService,
              syncClient: syncClient,
              screenTimeoutTimer: screenOffTimer,
              backgroundColorAnimationController:
                  backgroundColorAnimationController,
              interactionSubject: interactionSubject,
              child: MaterialApp(
                title: 'Glass Goals',
                theme: ThemeData(
                  primaryColor: Colors.black,
                  textTheme: const TextTheme(
                    bodyText1: TextStyle(color: Colors.white),
                    bodyText2: TextStyle(color: Colors.white),
                    headline1: mainTextStyle,
                  ),
                ),
                home: const GoalsHome(),
              ));
        });
  }
}

class GoalsHome extends StatelessWidget {
  const GoalsHome({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgAnimation =
        AppContext.of(context).backgroundColorAnimationController;
    return AnimatedBuilder(
      animation: bgAnimation,
      builder: (context, child) {
        return GlassScaffold(child: child);
      },
      child: GlassPageView(
        children: [
          GlassGestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StreamBuilder<Map<String, Goal>>(
                            stream:
                                AppContext.of(context).syncClient.stateSubject,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator()));
                              }
                              return GlassScaffold(
                                  child: GoalsWidget(snapshot.requireData,
                                      rootGoalId: rootGoal.id));
                            })));
              },
              child: Center(
                  child: Text("Goals",
                      style: Theme.of(context).textTheme.headline1))),
          GlassGestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const GlassScaffold(child: SettingsWidget())));
              },
              child: Center(
                  child: Text("Settings",
                      style: Theme.of(context).textTheme.headline1)))
        ],
      ),
    );
  }
}
