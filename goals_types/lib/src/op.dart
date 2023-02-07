import 'dart:convert' show jsonDecode, jsonEncode;

class GoalDelta {
  final String id;
  final String? text;
  final String? parentId;
  final String? activeUntil;
  const GoalDelta(
      {required this.id, this.text, this.parentId, this.activeUntil});

  static GoalDelta fromJson(dynamic jsonString) {
    final json = jsonDecode(jsonString);
    return GoalDelta(
      id: json['id'],
      text: json['text'],
      parentId: json['parentId'],
      activeUntil: json['activeUntil'],
    );
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
    if (delta.activeUntil != null) {
      json['activeUntil'] = delta.activeUntil!;
    }
    return jsonEncode(json);
  }
}

class Op {
  final GoalDelta delta;
  final String hlcTimestamp;
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
    return Op(
        hlcTimestamp: json['hlcTimestamp'],
        delta: GoalDelta.fromJson(json['delta']));
  }
}
