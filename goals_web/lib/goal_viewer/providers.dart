import 'package:goals_core/model.dart' show WorldContext;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:rxdart/rxdart.dart' show BehaviorSubject;

final selectedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final expandedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final focusedGoalProvider = StateNotifierProvider<_Id, String?>((ref) => _Id());

final worldContextProvider = StateNotifierProvider<_WorldContext, WorldContext>(
    (ref) => _WorldContext());

final isEditingTextProvider =
    StateNotifierProvider<_BooleanStateNotifier, bool>(
        (ref) => _BooleanStateNotifier(false));

final editingEventStream = BehaviorSubject<EditingEvent>();

final debugProvider = StateNotifierProvider<_BooleanStateNotifier, bool>(
    (ref) => _BooleanStateNotifier(false));

final hoverEventStream = BehaviorSubject<List<String>?>.seeded(null);

final textFocusProvider =
    StateNotifierProvider<_GoalPathNotifier, List<String>?>(
        (ref) => _GoalPathNotifier(null));

pathsMatch(List<String>? a, List<String>? b) {
  if (a == null && b == null) return true;
  if (a?.length != b?.length) {
    return false;
  }
  for (int i = 0; i < a!.length; i++) {
    if (a[i] != b![i]) return false;
  }
  return true;
}

enum EditingEvent {
  accept,
  discard,
}

class _BooleanStateNotifier extends StateNotifier<bool> {
  _BooleanStateNotifier(super.state);
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

class _GoalPathNotifier extends StateNotifier<List<String>?> {
  _GoalPathNotifier(super.state);
  void set(List<String>? value) => state = value;
}

class _WorldContext extends StateNotifier<WorldContext> {
  _WorldContext() : super(WorldContext.now());
  void poke() => state = WorldContext.now();
}

class _IdSet extends StateNotifier<Set<String>> {
  _IdSet() : super({});
  void add(String id) => state.add(id);
  void addAll(List<String> ids) => state.addAll(ids);
  void remove(String id) => state.remove(id);
  void toggle(String id) {
    if (state.contains(id)) {
      state.remove(id);
    } else {
      state.add(id);
    }
  }

  void clear() {
    state.clear();
  }
}

class _Id extends StateNotifier<String?> {
  _Id() : super(null);
  void set(String? id) {
    state = id;
  }
}
