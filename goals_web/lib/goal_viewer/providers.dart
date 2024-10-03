import 'package:goals_core/model.dart' show GoalPath, WorldContext;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show StateNotifier, StateNotifierProvider, StreamProvider;
import 'package:rxdart/rxdart.dart' show BehaviorSubject, CombineLatestStream;

import '../common/time_slice.dart';
import 'package:collection/collection.dart' show IterableExtension;

final selectedGoalsStream = BehaviorSubject<List<GoalPath>>.seeded([]);

final selectedGoalsProvider = StreamProvider((_) => selectedGoalsStream);

final expandedGoalsStream = BehaviorSubject<List<List<String>>>.seeded([]);

final expandedGoalsProvider = StreamProvider((_) => expandedGoalsStream);

togglePath(
    BehaviorSubject<List<List<String>>> pathListSubject, List<String> path) {
  final existingPathList = [...pathListSubject.value];
  if (pathListSubject.value.firstWhereOrNull((p) => pathsMatch(p, path)) !=
      null) {
    existingPathList.removeWhere((p) => pathsMatch(p, path));
  } else {
    existingPathList.add(path);
  }
  pathListSubject.add(existingPathList);
}

addPath(
    BehaviorSubject<List<List<String>>> pathListSubject, List<String> path) {
  if (pathListSubject.value.firstWhereOrNull((p) => pathsMatch(p, path)) !=
      null) return;
  final existingPathList = [...pathListSubject.value];
  existingPathList.add(path);
  pathListSubject.add(existingPathList);
}

removePath(
    BehaviorSubject<List<List<String>>> pathListSubject, List<String> path) {
  if (pathListSubject.value.firstWhereOrNull((p) => pathsMatch(p, path)) ==
      null) return;
  final existingPathList = [...pathListSubject.value];
  existingPathList.removeWhere((p) => pathsMatch(p, path));
  pathListSubject.add(existingPathList);
}

final focusedGoalStream = BehaviorSubject<String?>.seeded(null);
final focusedGoalProvider = StreamProvider((_) => focusedGoalStream);

final worldContextStream =
    BehaviorSubject<WorldContext>.seeded(WorldContext.now());
final worldContextProvider = StreamProvider((_) => worldContextStream);

final _manualTimeSlices = BehaviorSubject<
    List<({DateTime creationDateTime, TimeSlice slice})>>.seeded([]);

createManualTimeSlice(TimeSlice slice) async {
  final previousTimeSlices = [..._manualTimeSlices.value];
  previousTimeSlices.add((creationDateTime: DateTime.now(), slice: slice));
  _manualTimeSlices.add(previousTimeSlices);
}

/// This provider will return a list of time slices that we should show
/// even if they don't have any active goals within them.
final manualTimeSliceProvider = StreamProvider<List<TimeSlice>>((_) =>
    CombineLatestStream([worldContextStream, _manualTimeSlices], (values) {
      final [
        WorldContext ctx,
        List<({DateTime creationDateTime, TimeSlice slice})> manualTimeSlices
      ] = values as List<dynamic>;

      final now = ctx.time;

      final slices = <TimeSlice>[];
      for (final (:creationDateTime, :slice) in manualTimeSlices) {
        final sliceStartTime = slice.startTime(creationDateTime);
        final sliceEndTime = slice.endTime(creationDateTime);
        if ((sliceStartTime == null || now.isAfter(sliceStartTime)) &&
            (sliceEndTime == null || now.isBefore(sliceEndTime))) {
          slices.add(slice);
        }
      }
      return slices;
    }));

final debugProvider = StateNotifierProvider<_BooleanStateNotifier, bool>(
    (ref) => _BooleanStateNotifier(false));

final hasMouseProvider = StateNotifierProvider<_BooleanStateNotifier, bool>(
    (ref) => _BooleanStateNotifier(false));

final hoverEventStream = BehaviorSubject<List<String>?>.seeded(null);

final textFocusStream = BehaviorSubject<List<String>?>.seeded(null);
final textFocusProvider = StreamProvider((_) => textFocusStream);

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
