import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:goals_types_01/goals_types.dart' as goals_types_01;

const TYPES_VERSION = 2;

enum GoalStatus {
  pending,
  active,
  done,
  archived,
}

class StatusLogEntry {
  static const FIRST_VERSION = 2;

  final GoalStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  const StatusLogEntry({
    required this.status,
    this.startTime,
    this.endTime,
  });

  static StatusLogEntry fromJson(dynamic jsonString, int? version) {
    final json = jsonDecode(jsonString);
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return StatusLogEntry(
      status: GoalStatus.values.byName(json['status']),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
    );
  }

  static StatusLogEntry? fromActiveUntil(String? activeUntil) {
    if (activeUntil == null) {
      return null;
    }
    final activeUntilDateTime = DateTime.parse(activeUntil);
    return StatusLogEntry(
      status: GoalStatus.active,
      startTime: activeUntilDateTime.subtract(Duration(days: 1)),
      endTime: activeUntilDateTime,
    );
  }

  static String toJson(StatusLogEntry statusLogEntry) {
    return jsonEncode({
      'status': statusLogEntry.status.name,
      'startTime': statusLogEntry.startTime?.toIso8601String(),
      'endTime': statusLogEntry.endTime?.toIso8601String(),
    });
  }
}

class GoalDelta {
  final String id;
  final String? text;
  final String? parentId;
  final StatusLogEntry? statusLogEntry;
  const GoalDelta(
      {required this.id, this.text, this.parentId, this.statusLogEntry});

  static GoalDelta fromJson(dynamic jsonString, int? version) {
    final json = jsonDecode(jsonString);
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }
    if (version == null || version < TYPES_VERSION) {
      return fromV1(goals_types_01.GoalDelta.fromJson(jsonString));
    }
    return GoalDelta(
      id: json['id'],
      text: json['text'],
      parentId: json['parentId'],
      statusLogEntry: StatusLogEntry.fromJson(json['statusLogEntry'], version),
    );
  }

  static GoalDelta fromV1(goals_types_01.GoalDelta legacyGoalDelta) {
    return GoalDelta(
        id: legacyGoalDelta.id,
        text: legacyGoalDelta.text,
        parentId: legacyGoalDelta.parentId,
        statusLogEntry:
            StatusLogEntry.fromActiveUntil(legacyGoalDelta.activeUntil));
  }

  static String toJson(GoalDelta delta) {
    final json = {
      'id': delta.id,
    };
    if (delta.text != null) {
      json['text'] = delta.text!;
    }
    if (delta.parentId != null) {
      json['parentId'] = delta.parentId!;
    }
    if (delta.statusLogEntry != null) {
      json['statusLogEntry'] = StatusLogEntry.toJson(delta.statusLogEntry!);
    }
    return jsonEncode(json);
  }
}

class Op {
  final GoalDelta delta;
  final String hlcTimestamp;
  final int version = 2;
  const Op({
    required this.hlcTimestamp,
    required this.delta,
  });

  static String toJson(Op op) {
    return jsonEncode({
      'hlcTimestamp': op.hlcTimestamp,
      'delta': GoalDelta.toJson(op.delta),
    });
  }

  static Op fromJson(dynamic jsonString) {
    final json = jsonDecode(jsonString);
    final int? version = json['version'];
    return Op(
        hlcTimestamp: json['hlcTimestamp'],
        delta: GoalDelta.fromJson(json['delta'], version));
  }
}
