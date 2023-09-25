import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;

final selectedGoalsProvider =
    StateNotifierProvider<IdList, Set<String>>((ref) => IdList());

final expandedGoalsProvider =
    StateNotifierProvider<IdList, Set<String>>((ref) => IdList());

class IdList extends StateNotifier<Set<String>> {
  IdList() : super({});
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
