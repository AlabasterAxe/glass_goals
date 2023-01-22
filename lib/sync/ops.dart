import 'dart:convert' show jsonDecode, jsonEncode;

class GoalDelta {
  final String id;
  final String? text;
  final String? parentId;
  const GoalDelta({required this.id, this.text, this.parentId});

  static GoalDelta fromJson(dynamic jsonString) {
    final json = jsonDecode(jsonString);
    return GoalDelta(
        id: json['id'], text: json['text'], parentId: json['parentId']);
  }

  static String toJson(GoalDelta delta) {
    return jsonEncode({
      'id': delta.id,
      'text': delta.text,
      'parentId': delta.parentId,
    });
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
