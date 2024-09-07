import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/widgets.dart';
import 'package:goals_web/app_context.dart';
import 'package:goals_web/debug/debug_sync_info.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoals =
        ref.watch(selectedGoalsProvider).value ?? selectedGoalsStream.value;
    final textEditingPath =
        ref.watch(textFocusProvider).value ?? textFocusStream.value;

    return Container(
      key: const ValueKey('debug'),
      color: Colors.black.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UI State', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Selected Goals: ${selectedGoals.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Text Focus: ${textEditingPath?.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text('Focused Thing: ${FocusManager.instance.primaryFocus}'),
          StreamBuilder<List<String>?>(
              stream: hoverEventStream.stream,
              builder: (context, snapshot) {
                return Text('Hovered Path: ${snapshot.data}',
                    style: Theme.of(context).textTheme.bodySmall);
              }),
          DebugSyncInfo(
            syncClient: AppContext.of(context).syncClient,
          ),
        ],
      ),
    );
  }
}
