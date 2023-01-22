import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_goals/styles.dart';

import 'app_context.dart' show AppContext;
import 'glass_scaffold.dart';
import 'goal.dart' show GoalWidget, GoalTitle;
import 'model.dart' show Goal;
import 'stt_service.dart' show SttService;
import 'sync/sync_client.dart' show SyncClient;

void main() {
  runApp(const GlassGoals());
}

final rootGoal = Goal(id: '0', text: 'Live a fulfilling life', subGoals: [
  Goal(id: '1', text: 'Succeed Professionally'),
  Goal(id: '2', text: 'Create things'),
]);

class GlassGoals extends StatefulWidget {
  const GlassGoals({super.key});

  @override
  State<GlassGoals> createState() => _GlassGoalsState();
}

class _GlassGoalsState extends State<GlassGoals> {
  SttService sttService = SttService();
  SyncClient syncClient = SyncClient();

  Future<void> appInit() async {
    await syncClient.init();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<Goal>>(
          stream: AppContext.of(context).syncClient.stateSubject,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()));
            }
            return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 20) {
                    SystemNavigator.pop();
                  }
                },
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GlassScaffold(
                              child: GoalWidget(snapshot.requireData[0]))));
                },
                child: Center(
                    child: Hero(
                        tag: rootGoal.id,
                        child: GoalTitle(snapshot.requireData[0],
                            key: ValueKey(snapshot.requireData[0].id)))));
          }),
    );
  }
}
