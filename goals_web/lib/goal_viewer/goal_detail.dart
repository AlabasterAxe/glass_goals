import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart' show NoteLogEntry;
import 'package:goals_web/goal_viewer/add_note_card.dart' show AddNoteCard;

class GoalDetail extends StatelessWidget {
  final Goal goal;
  const GoalDetail({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AddNoteCard(goalId: goal.id),
      for (final entry in goal.log.whereType<NoteLogEntry>())
        Card(child: Markdown(data: entry.text))
    ]);
  }
}
