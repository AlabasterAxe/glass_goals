import 'dart:ui' show Locale;

import 'package:flutter/material.dart'
    show Dialog, IconButton, Icons, TextButton, showDatePicker;
import 'package:flutter/rendering.dart' show MainAxisAlignment;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Icon,
        IntrinsicHeight,
        IntrinsicWidth,
        Navigator,
        Row,
        State,
        StatefulWidget,
        Text,
        Widget;

final FOREVER = DateTime(2200);

class DatePickerDialog extends StatefulWidget {
  final Widget title;
  const DatePickerDialog({
    super.key,
    required this.title,
  });

  @override
  State<DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<DatePickerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Column(
            children: [
              widget.title,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(FOREVER);
                      },
                      child: const Text('Forever')),
                  IconButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          locale: const Locale('en', 'GB'),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop(date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today))
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
