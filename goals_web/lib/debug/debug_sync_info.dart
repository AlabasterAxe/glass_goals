import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart' show SyncClient;

class DebugSyncInfo extends StatelessWidget {
  final SyncClient syncClient;
  const DebugSyncInfo({
    super.key,
    required this.syncClient,
  });

  List<Widget> buildUndoStack() {
    return syncClient.undoStack
        .map((action) => Text(syncClient.modificationMap[action].toString()))
        .toList();
  }

  List<Widget> buildRedoStack() {
    return syncClient.redoStack
        .map((action) => Text(syncClient.modificationMap[action].toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
        stream: syncClient.syncSubject,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sync Info', style: Theme.of(context).textTheme.titleMedium),
              Text('Cursor: ${syncClient.cursor}'),
              Text('Last Sync Time: ${syncClient.lastSyncTime}'),
              Text('Num Unsynced Ops: ${syncClient.numUnsyncedOps}'),
              Text('Undo Stack:'),
              ...this.buildUndoStack(),
              Text('Redo Stack:'),
              ...this.buildRedoStack(),
            ],
          );
        });
  }
}
