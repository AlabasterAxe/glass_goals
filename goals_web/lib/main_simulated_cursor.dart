import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'package:goals_core/sync.dart' show InMemoryPersistenceService;
import 'package:goals_web/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart' show Hive, HiveX;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;

import 'app.dart';

class FalseCursor extends StatefulWidget {
  final Widget child;
  final enabled;
  const FalseCursor({Key? key, required this.child, this.enabled = true})
      : super(key: key);

  @override
  State<FalseCursor> createState() => _FalseCursorState();
}

class _FalseCursorState extends State<FalseCursor> {
  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
        onHover: (event) {
          this.setState(() {
            x = event.position.dx;
            y = event.position.dy;
          });
        },
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Positioned.fill(
              child: this.widget.child,
            ),
            if (this.widget.enabled)
              Positioned(
                  left: x,
                  top: y,
                  height: 24,
                  width: 24,
                  child: IgnorePointer(
                    child: Image(
                        image: AssetImage('assets/cursor.png'),
                        filterQuality: FilterQuality.high),
                  )),
          ],
        ));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  usePathUrlStrategy();
  runApp(FalseCursor(
      // enabled: false,
      child: ProviderScope(
          child: WebGoals(
              shouldAuthenticate: false,
              persistenceService: InMemoryPersistenceService(ops: [])))));
}
