import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/rendering.dart' show MainAxisAlignment;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Column,
        Navigator,
        StatelessWidget,
        Text,
        ValueListenableBuilder,
        Widget;
import '../util/glass_page_view.dart' show GlassPageView;
import 'package:hive_flutter/hive_flutter.dart';

import '../app_context.dart' show AppContext;
import '../styles.dart' show mainTextStyle, subTitleStyle;
import '../util/glass_gesture_detector.dart' show GlassGestureDetector;
import '../util/glass_scaffold.dart' show GlassScaffold;

class SettingsPage extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  final String? subtitle;
  const SettingsPage({
    super.key,
    this.onTap,
    required this.text,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassGestureDetector(
      onTap: onTap,
      child: Center(
        child: subtitle == null
            ? Text(text, style: mainTextStyle)
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(text, style: mainTextStyle),
                Text(subtitle!, style: subTitleStyle),
              ]),
      ),
    );
  }
}

String formatSyncTimeAsDelta(String? syncTime) {
  if (syncTime == null) {
    return 'never';
  }

  final duration = DateTime.now().difference(DateTime.parse(syncTime));
  final int days = duration.inDays;
  final int hours = duration.inHours % 24;
  final int minutes = duration.inMinutes % 60;
  final int seconds = duration.inSeconds % 60;
  final int milliseconds = duration.inMilliseconds % 1000;

  if (days > 1) {
    return '$days days ago';
  }
  if (days == 1) {
    return 'a day ago';
  }
  if (hours > 1) {
    return '$hours hours ago';
  }
  if (hours == 1) {
    return 'an hour ago';
  }
  if (minutes > 1) {
    return '$minutes minutes ago';
  }
  if (minutes == 1) {
    return 'a minute ago';
  }
  if (seconds > 10) {
    return '$seconds seconds ago';
  }

  return 'just now';
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
              text: 'Syncing',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GlassScaffold(
                          child: GlassPageView(children: [
                        ValueListenableBuilder(
                            valueListenable: Hive.box('glass_goals.sync')
                                .listenable(keys: ['lastSyncDateTime']),
                            builder: (context, box, _) {
                              final String? syncDateTimeString =
                                  box.get('lastSyncDateTime');
                              return SettingsPage(
                                text: 'Sync Now',
                                subtitle:
                                    "Last Sync: ${formatSyncTimeAsDelta(syncDateTimeString)}",
                                onTap: () async {
                                  AppContext.of(context).syncClient.sync();
                                },
                              );
                            }),
                        ValueListenableBuilder(
                            valueListenable: Hive.box('glass_goals.sync')
                                .listenable(keys: ['syncCursor']),
                            builder: (context, box, _) {
                              final int? cursor = box.get('syncCursor');
                              return SettingsPage(
                                text: 'Reset Sync Cursor',
                                subtitle:
                                    "Current: ${cursor != null ? cursor.toString() : 'unset'}",
                                onTap: () async {
                                  await Hive.box('glass_goals.sync')
                                      .delete('syncCursor');
                                },
                              );
                            }),
                      ])),
                    ));
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
