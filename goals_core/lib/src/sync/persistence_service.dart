import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart' show GSheets, Worksheet;

import 'package:goals_types/goals_types.dart' show GoalDelta, Op;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' show jsonDecode;

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
  Future<void> save(Iterable<Op> ops);
  Future<LoadOpsResp> load({int? cursor});
}

class GoogleSheetsPersistenceService implements PersistenceService {
  late Worksheet opsSheet;
  bool initted = false;

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

class FirestorePersistenceService implements PersistenceService {
  final db = FirebaseFirestore.instance;
  final seenOps = <String>{};

  @override
  Future<LoadOpsResp> load({int? cursor}) async {
    List<Op> newOps = [];
    final allRows = await db
        .collection('ops')
        .where('viewers', arrayContains: FirebaseAuth.instance.currentUser!.uid)
        .get();

    for (final row in allRows.docs) {
      final rowData = row.data();
      final delta = GoalDelta.fromJson(rowData['delta'], rowData['version']);
      final hlcTimestamp = row.id;
      newOps.add(Op(hlcTimestamp: hlcTimestamp, delta: delta));
    }

    return LoadOpsResp(newOps, 0);
  }

  @override
  Future<void> save(Iterable<Op> ops) async {
    final futures = <Future>[];

    for (final op in ops) {
      futures.add(db.collection('ops').doc(op.hlcTimestamp).set({
        'version': op.version,
        'delta': GoalDelta.toJson(op.delta),
        'viewers': [FirebaseAuth.instance.currentUser!.uid],
      }));
    }

    await Future.wait(futures);
  }
}
