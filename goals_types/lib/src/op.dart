import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:goals_types_02/goals_types.dart' as prev_goal_types;
import 'package:equatable/equatable.dart' show Equatable;

import 'version.dart' show TYPES_VERSION;

enum GoalStatus {
  pending,
  active,
  done,
  archived,
}

fromPreviousGoalStatus(prev_goal_types.GoalStatus? status) {
  switch (status) {
    case prev_goal_types.GoalStatus.pending:
      return GoalStatus.pending;
    case prev_goal_types.GoalStatus.active:
      return GoalStatus.active;
    case prev_goal_types.GoalStatus.done:
      return GoalStatus.done;
    case prev_goal_types.GoalStatus.archived:
      return GoalStatus.archived;
    case null:
      return null;
  }
}

abstract class GoalLogEntry extends Equatable {
  static const FIRST_VERSION = 3;
  final DateTime creationTime;
  const GoalLogEntry({required this.creationTime});
  static GoalLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version == null || version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }

    if (json is! Map) {
      throw Exception('Invalid data: $json is not a map');
    }

    final type = json['type'];
    if (type == null) {
      throw Exception('Invalid data: $json is missing type');
    }

    switch (type) {
      case 'note':
        return NoteLogEntry.fromJsonMap(json, version);
      case 'status':
        return StatusLogEntry.fromJsonMap(json, version);
      case 'archiveNote':
        return ArchiveNoteLogEntry.fromJsonMap(json, version);
      default:
        throw Exception('Invalid data: $json has unknown type: $type');
    }
  }

  static Map<String, dynamic> toJsonMap(GoalLogEntry entry) {
    if (entry is StatusLogEntry) {
      return StatusLogEntry.toJsonMap(entry);
    }
    if (entry is NoteLogEntry) {
      return NoteLogEntry.toJsonMap(entry);
    }
    if (entry is ArchiveNoteLogEntry) {
      return ArchiveNoteLogEntry.toJsonMap(entry);
    }
    throw Exception('Unknown type: ${entry.runtimeType}');
  }
}

class NoteLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 3;
  final String text;
  final String id;
  const NoteLogEntry({
    required super.creationTime,
    required this.text,
    required this.id,
  });

  @override
  List<Object?> get props => [id, creationTime, text];

  static NoteLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return NoteLogEntry(
      id: json['id'],
      text: json['text'],
      creationTime: json['creationTime'] != null
          ? DateTime.parse(json['creationTime']).toLocal()
          : DateTime(2023, 1, 1),
    );
  }

  static Map<String, dynamic> toJsonMap(NoteLogEntry noteLogEntry) {
    return {
      'type': 'note',
      'id': noteLogEntry.id,
      'text': noteLogEntry.text,
      'creationTime': noteLogEntry.creationTime.toUtc().toIso8601String(),
    };
  }
}

class ArchiveNoteLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 3;
  final String id;
  const ArchiveNoteLogEntry({
    required super.creationTime,
    required this.id,
  });

  @override
  List<Object?> get props => [id, creationTime];

  static ArchiveNoteLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return ArchiveNoteLogEntry(
      id: json['id'],
      creationTime: json['creationTime'] != null
          ? DateTime.parse(json['creationTime']).toLocal()
          : DateTime(2023, 1, 1),
    );
  }

  static Map<String, dynamic> toJsonMap(ArchiveNoteLogEntry entry) {
    return {
      'type': 'archiveNote',
      'id': entry.id,
      'creationTime': entry.creationTime.toUtc().toIso8601String(),
    };
  }
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
      status: json['status'] != null
          ? GoalStatus.values.byName(json['status'])
          : null,
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

  static StatusLogEntry? fromPrevious(
      prev_goal_types.StatusLogEntry? legacyEntry) {
    if (legacyEntry == null) {
      return null;
    }

    return StatusLogEntry(
      status: fromPreviousGoalStatus(legacyEntry.status),
      creationTime: legacyEntry.creationTime,
      startTime: legacyEntry.startTime,
      endTime: legacyEntry.endTime,
    );
  }

  static Map<String, dynamic> toJsonMap(StatusLogEntry statusLogEntry) {
    return {
      'type': 'status',
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
  static const STATUS_LOG_ENTRY_FIELD_NAME = 'logEntry';

  final String id;
  final String? text;
  final String? parentId;
  final GoalLogEntry? logEntry;
  const GoalDelta({required this.id, this.text, this.parentId, this.logEntry});

  static GoalDelta fromJson(String jsonString, int? version) {
    return fromJsonMap(jsonDecode(jsonString), version);
  }

  static GoalDelta fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }
    if (version == null || version < TYPES_VERSION) {
      if (json is Map) {
        return fromPrevious(
            prev_goal_types.GoalDelta.fromJson(jsonEncode(json), version));
      } else {
        return fromPrevious(prev_goal_types.GoalDelta.fromJson(json, version));
      }
    }
    return GoalDelta(
      id: json[ID_FIELD_NAME],
      text: json[TEXT_FIELD_NAME],
      parentId: json[PARENT_ID_FIELD_NAME],
      logEntry: json[STATUS_LOG_ENTRY_FIELD_NAME] != null
          ? GoalLogEntry.fromJsonMap(json[STATUS_LOG_ENTRY_FIELD_NAME], version)
          : null,
    );
  }

  static GoalDelta fromPrevious(prev_goal_types.GoalDelta legacyGoalDelta) {
    return GoalDelta(
        id: legacyGoalDelta.id,
        text: legacyGoalDelta.text,
        parentId: legacyGoalDelta.parentId,
        logEntry: StatusLogEntry.fromPrevious(legacyGoalDelta.statusLogEntry));
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
    if (delta.logEntry != null) {
      json[STATUS_LOG_ENTRY_FIELD_NAME] =
          GoalLogEntry.toJsonMap(delta.logEntry!);
    }
    return json;
  }

  static String toJson(GoalDelta delta) {
    return jsonEncode(toJsonMap(delta));
  }

  @override
  List<Object?> get props => [id, text, parentId, logEntry];
}

class Op extends Equatable {
  final GoalDelta delta;
  final String hlcTimestamp;
  final int version = TYPES_VERSION;
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
