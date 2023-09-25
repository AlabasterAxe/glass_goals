import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider;

final selectedGoals =
    StateNotifierProvider<IdList, Set<String>>((ref) => IdList());

final expandedGoals =
    StateNotifierProvider<IdList, Set<String>>((ref) => IdList());

class IdList extends StateNotifier<Set<String>> {
  IdList() : super({});
  void add(String id) => state.add(id);
  void remove(String id) => state.remove(id);
}
