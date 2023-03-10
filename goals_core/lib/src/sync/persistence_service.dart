import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart' show GSheets, Worksheet;

import 'package:goals_types/goals_types.dart' show GoalDelta, Op;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' show jsonDecode, jsonEncode;

Future<Map<String, dynamic>> loadSheetsSpec() async {
  if (kIsWeb) {
    return jsonDecode(await rootBundle.loadString('local/sheet_creds.json'));
  }
  return jsonDecode(
      await rootBundle.loadString('assets/local/sheet_creds.json'));
}

class LoadOpsResp {
  final List<Op> ops;
  final int cursor;
  LoadOpsResp(this.ops, this.cursor);
}

abstract class PersistenceService {
  Future<void> init();
  Future<void> save(Iterable<Op> ops);
  Future<LoadOpsResp> load({int? cursor});
}

class GoogleSheetsPersistenceService implements PersistenceService {
  late Worksheet opsSheet;
  bool initted = false;

  @override
  Future<void> init() async {
    if (initted) return;
    final sheetsSpec = await loadSheetsSpec();
    final gSheets = GSheets(sheetsSpec['service_account_key']);

    final Worksheet? sheet =
        (await gSheets.spreadsheet(sheetsSpec['spreadsheet_id']))
            .worksheetByIndex(0);
    if (sheet == null) {
      throw Exception("Could not find sheet");
    }
    opsSheet = sheet;
    initted = true;
  }

  @override
  Future<LoadOpsResp> load({int? cursor}) async {
    if (!initted) {
      await init();
    }
    cursor ??= 2;

    List<Op> newOps = [];
    final List<List<String>> newRows =
        await opsSheet.values.allRows(fromRow: cursor);

    for (final row in newRows) {
      final delta = GoalDelta.fromJson(row[1], int.parse(row[0]));
      final hlcTimestamp = row[2];
      newOps.add(Op(hlcTimestamp: hlcTimestamp, delta: delta));
    }

    final newCursor = cursor + newRows.length;

    return LoadOpsResp(newOps, newCursor);
  }

  @override
  Future<void> save(Iterable<Op> ops) async {
    if (!initted) {
      await init();
    }

    final success = await opsSheet.values.appendRows([
      for (var op in ops)
        [op.version, GoalDelta.toJson(op.delta), op.hlcTimestamp]
    ]);

    if (!success) {
      throw Exception("Failed to save ops");
    }
  }
}
