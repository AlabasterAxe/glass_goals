import 'package:goals_core/model.dart' show WorldContext;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;

final selectedGoalsProvider =
    StateNotifierProvider<_IdList, Set<String>>((ref) => _IdList());

final expandedGoalsProvider =
    StateNotifierProvider<_IdList, Set<String>>((ref) => _IdList());

final focusedGoalProvider = StateNotifierProvider<_Id, String?>((ref) => _Id());

final worldContextProvider = StateNotifierProvider<_WorldContext, WorldContext>(
    (ref) => _WorldContext());

final focusPathProvider =
    StateNotifierProvider<_IdList, Set<String>>((ref) => _IdList());

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

class _IdList extends StateNotifier<Set<String>> {
  _IdList() : super({});
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
