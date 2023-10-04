import 'dart:ui';

import 'package:flutter/material.dart'
    show Colors, IconButton, Icons, Tooltip, showDialog;
import 'package:flutter/painting.dart' show BorderRadius;
import 'package:flutter/rendering.dart' show BoxShadow;
import 'package:flutter/widgets.dart'
    show
        BoxDecoration,
        BuildContext,
        Container,
        Icon,
        MainAxisAlignment,
        Row,
        StatelessWidget,
        Text,
        Widget;
import '../widgets/date_picker.dart' show DatePickerDialog;

class HoverToolbarWidget extends StatelessWidget {
  final Function() onMerge;
  final Function() onUnarchive;
  final Function() onArchive;
  final Function() onDone;
  final Function(DateTime? endDate) onSnooze;
  final Function() onClearSelection;
  final Function(DateTime? endDate) onActive;
  const HoverToolbarWidget({
    super.key,
    required this.onMerge,
    required this.onUnarchive,
    required this.onArchive,
    required this.onDone,
    required this.onSnooze,
    required this.onActive,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Tooltip(
              message: 'Merge',
              child: IconButton(
                icon: const Icon(Icons.merge),
                onPressed: onMerge,
              ),
            ),
            Tooltip(
              message: 'Unarchive',
              child: IconButton(
                icon: const Icon(Icons.unarchive),
                onPressed: onUnarchive,
              ),
            ),
            Tooltip(
              message: 'Archive',
              child: IconButton(
                icon: const Icon(Icons.archive),
                onPressed: onArchive,
              ),
            ),
            Tooltip(
              message: 'Activate',
              child: IconButton(
                icon: const Icon(Icons.directions_run),
                onPressed: () async {
                  final DateTime? date = await showDialog(
                    context: context,
                    builder: (context) =>
                        const DatePickerDialog(title: Text('Active Until?')),
                  );
                  onActive(date);
                },
              ),
            ),
            Tooltip(
              message: 'Snooze',
              child: IconButton(
                icon: const Icon(Icons.snooze),
                onPressed: () async {
                  final DateTime? date = await showDialog(
                    context: context,
                    builder: (context) =>
                        const DatePickerDialog(title: Text('Snooze Until?')),
                  );
                  onSnooze(date);
                },
              ),
            ),
            Tooltip(
              message: 'Mark Done',
              child: IconButton(
                icon: const Icon(Icons.done),
                onPressed: onDone,
              ),
            ),
            Tooltip(
              message: 'Clear Selection',
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClearSelection,
              ),
            ),
          ],
        ));
  }
}
