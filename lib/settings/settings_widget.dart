import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Container,
        Navigator,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        ValueListenableBuilder,
        Widget;
import 'package:glass_goals/util/glass_page_view.dart' show GlassPageView;
import 'package:hive_flutter/hive_flutter.dart';

import '../styles.dart' show mainTextStyle;
import '../util/glass_gesture_detector.dart' show GlassGestureDetector;
import '../util/glass_scaffold.dart';

class SettingsPage extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const SettingsPage({
    super.key,
    this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GlassGestureDetector(
      onTap: onTap,
      child: Center(
        child: Text(text, style: mainTextStyle),
      ),
    );
  }
}

class SettingsWidget extends StatelessWidget {
  const SettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: Hive.box('glass_goals.settings').listenable(),
        builder: (context, box, _) {
          return GlassPageView(children: [
            SettingsPage(
              text: 'Reset Sync Cursor',
              onTap: () async {
                final box = Hive.box('glass_goals.sync');
                await box.put('syncCursor', 0);
              },
            ),
            SettingsPage(
              text: 'Hinting',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlassScaffold(
                      child: GlassPageView(
                        children: [
                          SettingsPage(
                            text: box.get('enableHinting', defaultValue: true)
                                ? 'Disable Hinting'
                                : 'Enable Hinting',
                            onTap: () {
                              box.put(
                                  'enableHinting',
                                  !box.get('enableHinting',
                                      defaultValue: true));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ]);
        });
  }
}
