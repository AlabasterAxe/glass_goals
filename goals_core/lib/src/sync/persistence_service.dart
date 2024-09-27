import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldPath, FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';

import 'package:goals_types/goals_types.dart' show DeltaOp, GoalDelta, Op;
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
  final int? cursor;
  LoadOpsResp(this.ops, this.cursor);
}

abstract class PersistenceService {
  Future<void> save(Iterable<Op> ops);
  Future<LoadOpsResp> load({int? cursor});
}

class FirestorePersistenceService implements PersistenceService {
  final db = FirebaseFirestore.instance;
  final seenOps = <String>{};
  final bool readonly;

  FirestorePersistenceService({this.readonly = false});

  @override
  Future<LoadOpsResp> load({int? cursor}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return LoadOpsResp([], null);
    }
    List<Op> newOps = [];
    var rowQuery = db
        .collection('ops')
        .where('viewers', arrayContains: FirebaseAuth.instance.currentUser!.uid)
        .orderBy(FieldPath.documentId);
    if (cursor != null) {
      // look up to 90 seconds in the past
      // the server allows ops to be up to 60 seconds in the past
      // so we accommodate up to 30 seconds of clock drift
      rowQuery = rowQuery.startAfter(['00${cursor - 90000}']);
    }

    final allRows = await rowQuery.get();

    for (final row in allRows.docs) {
      final rowData = row.data();
      if (rowData['version'] < 5) {
        newOps.add(fromPreV5Op(row.id, rowData));
      } else {
        newOps.add(Op.fromJsonMap(rowData));
      }
    }

    return LoadOpsResp(newOps, DateTime.now().millisecondsSinceEpoch);
  }

  Op fromPreV5Op(String rowId, Map<String, dynamic> previousOp) {
    final delta =
        GoalDelta.fromJson(previousOp['delta'], previousOp['version']);
    final hlcTimestamp = rowId;
    return DeltaOp(hlcTimestamp: hlcTimestamp, delta: delta);
  }

  @override
  Future<void> save(Iterable<Op> ops) async {
    if (readonly) {
      return;
    }
    final futures = <Future>[];

    for (final op in ops) {
      final rowData = Op.toJsonMap(op);
      rowData['viewers'] = [FirebaseAuth.instance.currentUser!.uid];
      futures.add(db.collection('ops').doc(op.hlcTimestamp).set(rowData));
    }

    await Future.wait(futures);
  }
}

class InMemoryPersistenceService implements PersistenceService {
  List<Op> ops = [];

  InMemoryPersistenceService({List<Map<String, dynamic>> ops = const []}) {
    for (final op in ops) {
      this.ops.add(Op.fromJsonMap(op));
    }
  }

  @override
  Future<LoadOpsResp> load({int? cursor}) async {
    return LoadOpsResp(ops, 0);
  }

  @override
  Future<void> save(Iterable<Op> ops) async {
    this.ops.addAll(ops);
  }
}
