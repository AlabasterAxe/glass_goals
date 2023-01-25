import 'package:gsheets/gsheets.dart'
    show Cell, GSheets, Spreadsheet, Worksheet;
import 'package:hive/hive.dart';

import 'ops.dart' show GoalDelta, Op;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' show jsonDecode;

Future<Map<String, dynamic>> loadSheetsSpec() async {
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
  Future<void> save(List<Op> ops);
  Future<LoadOpsResp> load(int cursor);
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
  Future<LoadOpsResp> load(int cursor) async {
    if (!initted) {
      await init();
    }

    List<Cell> row = [];
    int newCursor = cursor;
    List<Op> ops = [];
    do {
      if (newCursor < 1) {
        newCursor = 1;
      }
      row = await opsSheet.cells.row(newCursor + 1);
      if (row.isEmpty) {
        break;
      }
      newCursor++;
      final delta = GoalDelta.fromJson(row[0].value);
      final hlc = row[1].value;
      ops.add(Op(hlcTimestamp: hlc, delta: delta));
    } while (row.isNotEmpty);

    return LoadOpsResp(ops, newCursor);
  }

  @override
  Future<void> save(List<Op> ops) async {
    if (!initted) {
      await init();
    }
    final numRows = opsSheet.rowCount;
    final success = await opsSheet.add(rows: ops.length);
    if (!success) {
      throw Exception("Failed to save ops");
    }
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final row = await Future.wait([
        opsSheet.cells.cell(row: numRows + i + 1, column: 1),
        opsSheet.cells.cell(row: numRows + i + 1, column: 2),
      ]);
      final deltaCell = row[0];
      final hlcCell = row[1];

      await Future.wait([
        deltaCell.post(GoalDelta.toJson(op.delta)),
        hlcCell.post(op.hlcTimestamp),
      ]);
    }
  }
}
