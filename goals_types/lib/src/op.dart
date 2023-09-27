import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:goals_types_01/goals_types.dart' as goals_types_01;
import 'package:equatable/equatable.dart' show Equatable;

const TYPES_VERSION = 2;

enum GoalStatus {
  pending,
  active,
  done,
  archived,
}

abstract class GoalLogEntry extends Equatable {
  final DateTime creationTime;
  const GoalLogEntry({required this.creationTime});
}

class NoteLogEntry extends GoalLogEntry {
  final String text;
  const NoteLogEntry({
    required super.creationTime,
    required this.text,
  });

  @override
  List<Object?> get props => [creationTime, text];
}

class StatusLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 2;

  // a status log entry with a null status basically unsets the status
  // during the period it applies to.
  final GoalStatus? status;
  final DateTime? startTime;
  final DateTime? endTime;
  const StatusLogEntry({
    required super.creationTime,
    this.status,
    this.startTime,
    this.endTime,
  });

  static StatusLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return StatusLogEntry(
      status: GoalStatus.values.byName(json['status']),
      creationTime: json['creationTime'] != null
          ? DateTime.parse(json['creationTime']).toLocal()
          : DateTime(2023, 1, 1),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime']).toLocal()
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime']).toLocal()
          : null,
    );
  }

  static String toJson(StatusLogEntry entry) {
    return jsonEncode(toJsonMap(entry));
  }

  static StatusLogEntry fromJson(String json, int? version) {
    return fromJsonMap(jsonDecode(json), version);
  }

  static StatusLogEntry? fromActiveUntil(String? activeUntil) {
    if (activeUntil == null) {
      return null;
    }
    final activeUntilDateTime = DateTime.parse(activeUntil);
    final startTime = activeUntilDateTime.subtract(Duration(days: 1));
    return StatusLogEntry(
      status: GoalStatus.active,
      creationTime: startTime,
      startTime: startTime,
      endTime: activeUntilDateTime,
    );
  }

  static Map<String, dynamic> toJsonMap(StatusLogEntry statusLogEntry) {
    return {
      'status': statusLogEntry.status?.name,
      'creationTime': statusLogEntry.creationTime.toUtc().toIso8601String(),
      'startTime': statusLogEntry.startTime?.toUtc().toIso8601String(),
      'endTime': statusLogEntry.endTime?.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [status, startTime, endTime, creationTime];
}

class GoalDelta extends Equatable {
  static const ID_FIELD_NAME = 'id';
  static const TEXT_FIELD_NAME = 'text';
  static const PARENT_ID_FIELD_NAME = 'parentId';
  static const STATUS_LOG_ENTRY_FIELD_NAME = 'statusLogEntry';

  final String id;
  final String? text;
  final String? parentId;
  final StatusLogEntry? statusLogEntry;
  const GoalDelta(
      {required this.id, this.text, this.parentId, this.statusLogEntry});

  static GoalDelta fromJson(String jsonString, int? version) {
    return fromJsonMap(jsonDecode(jsonString), version);
  }

  static GoalDelta fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }
    if (version == null || version < TYPES_VERSION) {
      if (json is Map) {
        return fromV1(goals_types_01.GoalDelta.fromJson(jsonEncode(json)));
      } else {
        return fromV1(goals_types_01.GoalDelta.fromJson(json));
      }
    }
    return GoalDelta(
      id: json[ID_FIELD_NAME],
      text: json[TEXT_FIELD_NAME],
      parentId: json[PARENT_ID_FIELD_NAME],
      statusLogEntry: json[STATUS_LOG_ENTRY_FIELD_NAME] != null
          ? StatusLogEntry.fromJsonMap(
              json[STATUS_LOG_ENTRY_FIELD_NAME], version)
          : null,
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

  static Map<String, dynamic> toJsonMap(GoalDelta delta) {
    final Map<String, dynamic> json = {
      ID_FIELD_NAME: delta.id,
    };
    if (delta.text != null) {
      json[TEXT_FIELD_NAME] = delta.text!;
    }
    if (delta.parentId != null) {
      json[PARENT_ID_FIELD_NAME] = delta.parentId!;
    }
    if (delta.statusLogEntry != null) {
      json[STATUS_LOG_ENTRY_FIELD_NAME] =
          StatusLogEntry.toJsonMap(delta.statusLogEntry!);
    }
    return json;
  }

  static String toJson(GoalDelta delta) {
    return jsonEncode(toJsonMap(delta));
  }

  @override
  List<Object?> get props => [id, text, parentId, statusLogEntry];
}

class Op extends Equatable {
  final GoalDelta delta;
  final String hlcTimestamp;
  final int version = 2;
  const Op({
    required this.hlcTimestamp,
    required this.delta,
  });

  static Map<String, dynamic> toJsonMap(Op op) {
    return {
      'hlcTimestamp': op.hlcTimestamp,
      'delta': GoalDelta.toJsonMap(op.delta),
      'version': op.version,
    };
  }

  static Op fromJsonMap(dynamic json) {
    final int? version = json['version'];
    return Op(
        hlcTimestamp: json['hlcTimestamp'],
        delta: GoalDelta.fromJsonMap(json['delta'], version));
  }

  static Op fromJson(String jsonString) {
    return fromJsonMap(jsonDecode(jsonString));
  }

  static String toJson(Op op) {
    return jsonEncode(toJsonMap(op));
  }

  @override
  List<Object?> get props => [hlcTimestamp, delta];
}
