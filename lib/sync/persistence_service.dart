import 'package:gsheets/gsheets.dart' show GSheets, Spreadsheet, Worksheet;

import 'ops.dart' show GoalDelta, Op;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' show jsonDecode;

Future<Map<String, dynamic>> loadSheetsSpec() async {
  return jsonDecode(
      await rootBundle.loadString('assets/local/sheet_creds.json'));
}

class LoadOpsResp {
  final List<Op> ops;
  final String cursor;
  LoadOpsResp(this.ops, this.cursor);
}

abstract class PersistenceService {
  Future<void> init();
  Future<void> save(List<Op> ops);
  Future<LoadOpsResp> load(String cursor);
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
  Future<LoadOpsResp> load(String cursor) async {
    if (!initted) {
      await init();
    }

    throw UnimplementedError();
  }

  @override
  Future<void> save(List<Op> ops) async {
    if (!initted) {
      await init();
    }
    final success = await opsSheet.insertRow(2, count: ops.length);
    if (!success) {
      throw Exception("Failed to save ops");
    }
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final row = await opsSheet.cells.row(2 + i);
      final deltaCell = row[0];
      final hlcCell = row[1];

      await Future.wait([
        deltaCell.post(GoalDelta.toJson(op.delta)),
        hlcCell.post(op.hlcTimestamp),
      ]);
    }
  }
}
