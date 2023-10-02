import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:rxdart/subjects.dart' show BehaviorSubject, Subject;

final selectedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final expandedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final Subject<String?> focusedGoalSubject = BehaviorSubject.seeded(null);

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
