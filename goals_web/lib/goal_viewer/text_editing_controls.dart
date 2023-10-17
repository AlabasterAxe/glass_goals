import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../styles.dart';

class TextEditingControls extends StatelessWidget {
  const TextEditingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: uiUnit(15),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {},
          ),
        ),
        SizedBox(
          width: uiUnit(15),
          child: IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {},
          ),
        )
      ],
    );
  }
}
