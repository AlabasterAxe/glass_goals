import 'package:flutter_test/flutter_test.dart';
import 'package:goals_core/sync.dart' show InMemoryPersistenceService;
import 'package:goals_web/app.dart' show WebGoals;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('tap on the floating action button, verify counter',
        (tester) async {
      // Load app widget.
      await tester.pumpWidget(ProviderScope(
          child: WebGoals(
        shouldAuthenticate: false,
        persistenceService: InMemoryPersistenceService(),
      )));

      await tester.pumpAndSettle();

      expect(find.text('Scheduled Goals'), findsWidgets);
    });
  });
}
