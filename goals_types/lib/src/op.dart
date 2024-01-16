import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:goals_types_04/goals_types.dart' as prev_goal_types;
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
  final String id;
  const GoalLogEntry({required this.creationTime, required this.id});
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
      case 'archiveNote':
        return ArchiveNoteLogEntry.fromJsonMap(json, version);
      case 'status':
        return StatusLogEntry.fromJsonMap(json, version);
      case 'archiveStatus':
        return ArchiveStatusLogEntry.fromJsonMap(json, version);
      case 'setParent':
        return SetParentLogEntry.fromJsonMap(json, version);
      case 'priority':
        return PriorityLogEntry.fromJsonMap(json, version);
      default:
        throw Exception('Invalid data: $json has unknown type: $type');
    }
  }

  static Map<String, dynamic> toJsonMap(GoalLogEntry entry) {
    if (entry is StatusLogEntry) {
      return StatusLogEntry.toJsonMap(entry);
    }
    if (entry is ArchiveStatusLogEntry) {
      return ArchiveStatusLogEntry.toJsonMap(entry);
    }
    if (entry is NoteLogEntry) {
      return NoteLogEntry.toJsonMap(entry);
    }
    if (entry is ArchiveNoteLogEntry) {
      return ArchiveNoteLogEntry.toJsonMap(entry);
    }
    if (entry is SetParentLogEntry) {
      return SetParentLogEntry.toJsonMap(entry);
    }
    if (entry is PriorityLogEntry) {
      return PriorityLogEntry.toJsonMap(entry);
    }
    throw Exception('Unknown type: ${entry.runtimeType}');
  }

  static GoalLogEntry? fromPrevious(prev_goal_types.GoalLogEntry? legacyEntry) {
    if (legacyEntry == null) {
      return null;
    }
    if (legacyEntry is prev_goal_types.StatusLogEntry) {
      return StatusLogEntry.fromPrevious(legacyEntry);
    } else if (legacyEntry is prev_goal_types.ArchiveNoteLogEntry) {
      return ArchiveNoteLogEntry.fromPrevious(legacyEntry);
    } else if (legacyEntry is prev_goal_types.NoteLogEntry) {
      return NoteLogEntry.fromPrevious(legacyEntry);
    } else if (legacyEntry is prev_goal_types.SetParentLogEntry) {
      return SetParentLogEntry.fromPrevious(legacyEntry);
    } else if (legacyEntry is prev_goal_types.ArchiveStatusLogEntry) {
      return ArchiveStatusLogEntry.fromPrevious(legacyEntry);
    } else if (legacyEntry is prev_goal_types.PriorityLogEntry) {
      return PriorityLogEntry.fromPrevious(legacyEntry);
    } else {
      throw Exception('Unknown type: ${legacyEntry.runtimeType}');
    }
  }
}

class PriorityLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 4;
  final double? priority;
  const PriorityLogEntry({
    required super.creationTime,
    required super.id,
    required this.priority,
  });

  @override
  List<Object?> get props => [id, creationTime, priority];

  static PriorityLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return PriorityLogEntry(
      id: json['id'],
      priority: json['priority'],
      creationTime: DateTime.parse(json['creationTime']!).toLocal(),
    );
  }

  static Map<String, dynamic> toJsonMap(PriorityLogEntry entry) {
    return {
      'type': 'priority',
      'id': entry.id,
      'priority': entry.priority,
      'creationTime': entry.creationTime.toUtc().toIso8601String(),
    };
  }

  static PriorityLogEntry fromPrevious(
      prev_goal_types.PriorityLogEntry legacyEntry) {
    return PriorityLogEntry(
      id: legacyEntry.id,
      priority: legacyEntry.priority,
      creationTime: legacyEntry.creationTime,
    );
  }
}

class NoteLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 3;
  final String text;
  const NoteLogEntry({
    required super.creationTime,
    required super.id,
    required this.text,
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

  static NoteLogEntry? fromPrevious(prev_goal_types.NoteLogEntry? legacyEntry) {
    if (legacyEntry == null) {
      return null;
    }

    return NoteLogEntry(
      id: legacyEntry.id,
      text: legacyEntry.text,
      creationTime: legacyEntry.creationTime,
    );
  }
}

class ArchiveNoteLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 3;
  const ArchiveNoteLogEntry({
    required super.creationTime,
    required super.id,
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

  static ArchiveNoteLogEntry? fromPrevious(
      prev_goal_types.ArchiveNoteLogEntry? legacyEntry) {
    if (legacyEntry == null) {
      return null;
    }

    return ArchiveNoteLogEntry(
      id: legacyEntry.id,
      creationTime: legacyEntry.creationTime,
    );
  }
}

/// This log entry sets the parent of a goal, clearing other parents if any.
class SetParentLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 4;
  final String? parentId;
  const SetParentLogEntry({
    required super.id,
    required super.creationTime,
    required this.parentId,
  });

  @override
  List<Object?> get props => [id, parentId, creationTime];

  static SetParentLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    final creationTime = json['creationTime'] != null
        ? DateTime.parse(json['creationTime']).toLocal()
        : DateTime(2023, 1, 1);
    return SetParentLogEntry(
      id: json['id'] ?? '${creationTime.millisecondsSinceEpoch}',
      parentId: json['parentId'],
      creationTime: creationTime,
    );
  }

  static Map<String, dynamic> toJsonMap(SetParentLogEntry entry) {
    return {
      'type': 'setParent',
      'id': entry.id,
      'parentId': entry.parentId,
      'creationTime': entry.creationTime.toUtc().toIso8601String(),
    };
  }

  static GoalLogEntry fromPrevious(
      prev_goal_types.SetParentLogEntry legacyEntry) {
    return SetParentLogEntry(
      id: legacyEntry.id,
      parentId: legacyEntry.parentId,
      creationTime: legacyEntry.creationTime,
    );
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
    required super.id,
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
    final creationTime = json['creationTime'] != null
        ? DateTime.parse(json['creationTime']).toLocal()
        : DateTime(2023, 1, 1);
    return StatusLogEntry(
      id: json['id'] ?? '${creationTime.millisecondsSinceEpoch}',
      status: json['status'] != null
          ? GoalStatus.values.byName(json['status'])
          : null,
      creationTime: creationTime,
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
      id: '${legacyEntry.creationTime.millisecondsSinceEpoch}',
      status: fromPreviousGoalStatus(legacyEntry.status),
      creationTime: legacyEntry.creationTime,
      startTime: legacyEntry.startTime,
      endTime: legacyEntry.endTime,
    );
  }

  static Map<String, dynamic> toJsonMap(StatusLogEntry statusLogEntry) {
    return {
      'type': 'status',
      'id': statusLogEntry.id,
      'status': statusLogEntry.status?.name,
      'creationTime': statusLogEntry.creationTime.toUtc().toIso8601String(),
      'startTime': statusLogEntry.startTime?.toUtc().toIso8601String(),
      'endTime': statusLogEntry.endTime?.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, status, startTime, endTime, creationTime];

  @override
  String toString() {
    return 'Status: $status ${startTime != null ? 'from ${startTime}' : ''} ${endTime != null ? 'until ${endTime}' : ''} {id: $id, creationTime: $creationTime}';
  }
}

class ArchiveStatusLogEntry extends GoalLogEntry {
  static const FIRST_VERSION = 4;
  const ArchiveStatusLogEntry({
    required super.creationTime,
    required super.id,
  });

  @override
  List<Object?> get props => [id, creationTime];

  static ArchiveStatusLogEntry fromJsonMap(dynamic json, int? version) {
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }

    if (version != null && version < FIRST_VERSION) {
      throw Exception(
          'Invalid data: $version is before first version: $FIRST_VERSION');
    }
    return ArchiveStatusLogEntry(
      id: json['id'],
      creationTime: DateTime.parse(json['creationTime']).toLocal(),
    );
  }

  static Map<String, dynamic> toJsonMap(ArchiveStatusLogEntry entry) {
    return {
      'type': 'archiveStatus',
      'id': entry.id,
      'creationTime': entry.creationTime.toUtc().toIso8601String(),
    };
  }

  static ArchiveStatusLogEntry fromPrevious(
      prev_goal_types.ArchiveStatusLogEntry legacyEntry) {
    return ArchiveStatusLogEntry(
      id: legacyEntry.id,
      creationTime: legacyEntry.creationTime,
    );
  }
}

class GoalDelta extends Equatable {
  static const ID_FIELD_NAME = 'id';
  static const TEXT_FIELD_NAME = 'text';
  static const PARENT_ID_FIELD_NAME = 'parentId';
  static const LOG_ENTRY_FIELD_NAME = 'logEntry';

  final String id;
  final String? text;
  final GoalLogEntry? logEntry;
  const GoalDelta({required this.id, this.text, this.logEntry});

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
      logEntry: json[LOG_ENTRY_FIELD_NAME] != null
          ? GoalLogEntry.fromJsonMap(json[LOG_ENTRY_FIELD_NAME], version)
          : null,
    );
  }

  static GoalDelta fromPrevious(prev_goal_types.GoalDelta legacyGoalDelta) {
    if (legacyGoalDelta.logEntry != null) {
      return GoalDelta(
          id: legacyGoalDelta.id,
          text: legacyGoalDelta.text,
          logEntry: GoalLogEntry.fromPrevious(legacyGoalDelta.logEntry));
    } else {
      return GoalDelta(id: legacyGoalDelta.id, text: legacyGoalDelta.text);
    }
  }

  static Map<String, dynamic> toJsonMap(GoalDelta delta) {
    final Map<String, dynamic> json = {
      ID_FIELD_NAME: delta.id,
    };
    if (delta.text != null) {
      json[TEXT_FIELD_NAME] = delta.text!;
    }
    if (delta.logEntry != null) {
      json[LOG_ENTRY_FIELD_NAME] = GoalLogEntry.toJsonMap(delta.logEntry!);
    }
    return json;
  }

  static String toJson(GoalDelta delta) {
    return jsonEncode(toJsonMap(delta));
  }

  @override
  List<Object?> get props => [id, text, logEntry];
}

enum OpType {
  delta,
  disableOp,
  enableOp,
}

abstract class Op extends Equatable {
  final String hlcTimestamp;
  final int version = TYPES_VERSION;
  final OpType type;
  const Op({required this.hlcTimestamp, required this.type});

  static String toJson(Op op) {
    switch (op) {
      case DeltaOp op:
        return DeltaOp.toJson(op);
      case DisableOp op:
        return DisableOp.toJson(op);
      case EnableOp op:
        return EnableOp.toJson(op);
    }
    throw Exception('Unknown type: ${op.runtimeType}');
  }

  static Map<String, dynamic> toJsonMap(Op op) {
    switch (op) {
      case DeltaOp op:
        return DeltaOp.toJsonMap(op);
      case DisableOp op:
        return DisableOp.toJsonMap(op);
      case EnableOp op:
        return EnableOp.toJsonMap(op);
    }
    throw Exception('Unknown type: ${op.runtimeType}');
  }

  static Op fromJson(String jsonString) {
    return fromJsonMap(jsonDecode(jsonString));
  }

  static Op fromJsonMap(dynamic json) {
    final int? version = json['version'];
    if (version != null && version > TYPES_VERSION) {
      throw Exception('Unsupported version: $version');
    }
    if (version == null || version < TYPES_VERSION) {
      if (json is Map) {
        return fromPrevious(prev_goal_types.Op.fromJson(jsonEncode(json)));
      } else {
        return fromPrevious(prev_goal_types.Op.fromJson(json));
      }
    }
    final type = json['type'];
    if (type == null) {
      throw Exception('Invalid data: $json is missing type');
    }

    switch (type) {
      case 'delta':
        return DeltaOp.fromJsonMap(json);
      case 'disableOp':
        return DisableOp.fromJsonMap(json);
      case 'enableOp':
        return EnableOp.fromJsonMap(json);
      default:
        throw Exception('Invalid data: $json has unknown type: $type');
    }
  }

  static Op fromPrevious(prev_goal_types.Op legacyOp) {
    return DeltaOp.fromPrevious(legacyOp);
  }

  @override
  List<Object?> get props => [hlcTimestamp];
}

class DeltaOp extends Op {
  final GoalDelta delta;
  const DeltaOp({
    required hlcTimestamp,
    required this.delta,
  }) : super(hlcTimestamp: hlcTimestamp, type: OpType.delta);

  static Map<String, dynamic> toJsonMap(DeltaOp op) {
    return {
      'hlcTimestamp': op.hlcTimestamp,
      'delta': GoalDelta.toJsonMap(op.delta),
      'version': op.version,
      'type': 'delta',
    };
  }

  static DeltaOp fromJsonMap(dynamic json) {
    final int? version = json['version'];
    return DeltaOp(
        hlcTimestamp: json['hlcTimestamp'],
        delta: GoalDelta.fromJsonMap(json['delta'], version));
  }

  static DeltaOp fromJson(String jsonString) {
    return fromJsonMap(jsonDecode(jsonString));
  }

  static String toJson(DeltaOp op) {
    return jsonEncode(toJsonMap(op));
  }

  static DeltaOp fromPrevious(prev_goal_types.Op legacyOp) {
    return DeltaOp(
      hlcTimestamp: legacyOp.hlcTimestamp,
      delta: GoalDelta.fromPrevious(legacyOp.delta),
    );
  }
}

class DisableOp extends Op {
  final String hlcToDisable;
  const DisableOp({required hlcTimestamp, required this.hlcToDisable})
      : super(hlcTimestamp: hlcTimestamp, type: OpType.disableOp);

  static Map<String, dynamic> toJsonMap(DisableOp op) {
    return {
      'hlcTimestamp': op.hlcTimestamp,
      'version': op.version,
      'type': 'disableOp',
      'hlcToDisable': op.hlcToDisable,
    };
  }

  static DisableOp fromJsonMap(dynamic json) {
    return DisableOp(
        hlcTimestamp: json['hlcTimestamp'], hlcToDisable: json['hlcToDisable']);
  }

  static DisableOp fromJson(String jsonString) {
    return fromJsonMap(jsonDecode(jsonString));
  }

  static String toJson(DisableOp op) {
    return jsonEncode(toJsonMap(op));
  }

  static DisableOp fromPrevious(dynamic legacyOp) {
    throw Exception('No historical version of this op to convert from!');
  }
}

class EnableOp extends Op {
  final String hlcToEnable;
  const EnableOp({required hlcTimestamp, required this.hlcToEnable})
      : super(hlcTimestamp: hlcTimestamp, type: OpType.enableOp);

  static Map<String, dynamic> toJsonMap(EnableOp op) {
    return {
      'hlcTimestamp': op.hlcTimestamp,
      'version': op.version,
      'type': 'enableOp',
      'hlcToEnable': op.hlcToEnable,
    };
  }

  static EnableOp fromJsonMap(dynamic json) {
    return EnableOp(
        hlcTimestamp: json['hlcTimestamp'], hlcToEnable: json['hlcToEnable']);
  }

  static EnableOp fromJson(String jsonString) {
    return fromJsonMap(jsonDecode(jsonString));
  }

  static String toJson(EnableOp op) {
    return jsonEncode(toJsonMap(op));
  }

  static EnableOp fromPrevious(dynamic legacyOp) {
    throw Exception('No historical version of this op to convert from!');
  }
}
