import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;

final selectedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final expandedGoalsProvider =
    StateNotifierProvider<_IdSet, Set<String>>((ref) => _IdSet());

final focusedGoalProvider = StateNotifierProvider<_Id, String?>((ref) => _Id());

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
