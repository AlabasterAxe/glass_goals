import 'dart:convert' show jsonEncode;
import 'package:goals_types_01/goals_types.dart' as goals_types_01;
import 'package:equatable/equatable.dart' show Equatable;

const TYPES_VERSION = 2;

enum GoalStatus {
  pending,
  active,
  done,
  archived,
}

class StatusLogEntry extends Equatable {
  static const FIRST_VERSION = 2;

  final GoalStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  const StatusLogEntry({
    required this.status,
    this.startTime,
    this.endTime,
  });

  static StatusLogEntry fromJson(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return StatusLogEntry(
      status: GoalStatus.values.byName(json['status']),
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime:
          json['startTime'] != null ? DateTime.parse(json['endTime']) : null,
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

  static Map<String, dynamic> toJson(StatusLogEntry statusLogEntry) {
    return {
      'status': statusLogEntry.status.name,
      'startTime': statusLogEntry.startTime?.toIso8601String(),
      'endTime': statusLogEntry.endTime?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [status, startTime, endTime];
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

  static GoalDelta fromJson(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }
    if (version == null || version < TYPES_VERSION) {
      return fromV1(goals_types_01.GoalDelta.fromJson(json));
    }
    return GoalDelta(
      id: json[ID_FIELD_NAME],
      text: json[TEXT_FIELD_NAME],
      parentId: json[PARENT_ID_FIELD_NAME],
      statusLogEntry: json[STATUS_LOG_ENTRY_FIELD_NAME] != null
          ? StatusLogEntry.fromJson(json[STATUS_LOG_ENTRY_FIELD_NAME], version)
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

  static Map<String, dynamic> toJson(GoalDelta delta) {
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
          StatusLogEntry.toJson(delta.statusLogEntry!);
    }
    return json;
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

  static Map<String, dynamic> toJson(Op op) {
    return {
      'hlcTimestamp': op.hlcTimestamp,
      'delta': GoalDelta.toJson(op.delta),
      'version': op.version,
    };
  }

  static Op fromJson(dynamic json) {
    final int? version = json['version'];
    return Op(
        hlcTimestamp: json['hlcTimestamp'],
        delta: GoalDelta.fromJson(json['delta'], version));
  }

  @override
  List<Object?> get props => [hlcTimestamp, delta];
}
