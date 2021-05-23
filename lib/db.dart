import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'requests.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

final String columnId = "_id";
final String tableVault = 'vault';
final String columnDomainName = 'domainname';
final String columnDoc = 'doc';
final String columnLastUpdateTimeStamp = "lastUpdateTimeStamp";

class DecryptedDoc {
  String domainname;
  Map<String, dynamic> doc;
  int lastUpdateTimeStamp;
  DecryptedDoc(
      {@required this.domainname,
      @required this.doc,
      @required this.lastUpdateTimeStamp});
}

class EncryptedDoc {
  int id;
  String domainname;
  String doc;
  int lastUpdateTimeStamp;

  Map<String, Object> toMap() {
    var map = <String, Object>{
      columnDomainName: domainname,
      columnDoc: doc,
      columnLastUpdateTimeStamp: lastUpdateTimeStamp,
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  EncryptedDoc(
      {@required this.domainname,
      @required this.doc,
      this.lastUpdateTimeStamp});

  EncryptedDoc.fromMap(Map<String, Object> map) {
    id = map[columnId];
    domainname = map[columnDomainName];
    doc = map[columnDoc];
    lastUpdateTimeStamp = map[columnLastUpdateTimeStamp];
  }
}

class VaultHandler {
  Database db;

  VaultHandler();

  Future open() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String dbPath = appDir.path + "/vault.sqlite";
    db = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      print("Creating table");
      await db.execute('''
        CREATE TABLE $tableVault (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnDomainName TEXT UNIQUE ,
          $columnDoc TEXT NOT NULL,
          $columnLastUpdateTimeStamp INTEGER NOT NULL )
      ''');
      print("Creating db");
    });
  }

  Future<REQUEST_RESULT> syncVault({@required String appUrl}) async {
    /*
    Gets changes since specified lastUpdateTime and updates in local DB
    */
    ResultWithBody response = await getUpdatedList(
        urlPrefix: appUrl,
        lastUpdateTime: await this.lastUpdateTimeStamp() + 1);
    if (response.result == REQUEST_RESULT.SUCCESS) {
      for (int i = 0; i < response.body.length; i++) {
        insetOrUpdate(EncryptedDoc.fromMap(response.body[i]));
      }
      return REQUEST_RESULT.SUCCESS;
    } else {
      return response.result;
    }
  }

  Future<int> lastUpdateTimeStamp() async {
    var val = await db
        .rawQuery("SELECT MAX($columnLastUpdateTimeStamp) FROM $tableVault");
    return (val.first["MAX(lastUpdateTimeStamp)"] != null)
        ? val.first["MAX(lastUpdateTimeStamp)"]
        : 0;
  }

  void insetOrUpdate(EncryptedDoc newDoc) async {
    int existingDocID = await getExistingDocID(newDoc);
    if (existingDocID == null) {
      print("Adding Doc");
      await insert(newDoc);
    } else {
      newDoc.id = existingDocID;
      await update(newDoc);
      print("Updating Doc");
    }
  }

  Future<EncryptedDoc> insert(EncryptedDoc doc) async {
    doc.id = await db.insert(tableVault, doc.toMap());
    return doc;
  }

  Future<int> update(EncryptedDoc doc) async {
    return await db.update(tableVault, doc.toMap(),
        where: '$columnId = ?', whereArgs: [doc.id]);
  }

  Future<int> getExistingDocID(EncryptedDoc doc) async {
    List<Map<String, dynamic>> rawEncryptedDoc = await db.query(tableVault,
        columns: [
          columnId,
          columnDoc,
          columnDomainName,
          columnLastUpdateTimeStamp
        ],
        where: '$columnDomainName = ?',
        whereArgs: [doc.domainname]);
    if (rawEncryptedDoc.length > 0) {
      return EncryptedDoc.fromMap(rawEncryptedDoc.first).id;
    }
    return null;
  }

  Future<String> getEncryptedEncryptionKey() async {
    List<Map<String, dynamic>> rawEncryptedDoc = await db.query(tableVault,
        columns: [
          columnId,
          columnDoc,
          columnDomainName,
          columnLastUpdateTimeStamp
        ],
        where: '$columnDomainName = ?',
        whereArgs: ["encryptedEncryptionKey"]);
    if (rawEncryptedDoc.length > 0) {
      return EncryptedDoc.fromMap(rawEncryptedDoc.first).doc;
    }
    return null;
  }

  Future<List<DecryptedDoc>> getDecrypteDocs(String password) async {
    List<EncryptedDoc> docs = await getAllEncryptedDocsOmitDeleted();
    var encryptedEncryptionKey = await getEncryptedEncryptionKey();
    var encryptionKey = decrypt(
        body: encryptedEncryptionKey, password: genClientPassword(password));
    List<DecryptedDoc> out = [];
    for (int i = 0; i < docs.length; i++) {
      var decryptedCredential =
          b64decode(decrypt(body: docs[i].doc, password: encryptionKey));
      if (decryptedCredential == null) {
        return null;
      }
      out.add(DecryptedDoc(
          domainname: docs[i].domainname,
          doc: jsonDecode(decryptedCredential),
          lastUpdateTimeStamp: docs[i].lastUpdateTimeStamp));
    }
    return out;
  }

  Future<List<EncryptedDoc>> getAllEncryptedDocsOmitDeleted() async {
    List<Map<String, dynamic>> rawEncryptedDoc = await db.query(tableVault,
        columns: [
          columnId,
          columnDoc,
          columnDomainName,
          columnLastUpdateTimeStamp
        ],
        where: '$columnDoc != ? AND $columnDomainName != ?',
        whereArgs: ["", "encryptedEncryptionKey"]);
    return rawEncryptedDoc.map((Map<String, dynamic> rawDoc) {
      return EncryptedDoc.fromMap(rawDoc);
    }).toList();
  }

  Future<List<EncryptedDoc>> getAllEncryptedDocs() async {
    List<Map<String, dynamic>> rawEncryptedDoc = await db.query(
      tableVault,
      columns: [
        columnId,
        columnDomainName,
        columnDoc,
        columnLastUpdateTimeStamp
      ],
    );

    return rawEncryptedDoc.map((Map<String, dynamic> rawDoc) {
      return EncryptedDoc.fromMap(rawDoc);
    }).toList();
  }

  Future<int> delete(EncryptedDoc doc) async {
    return await db
        .delete(tableVault, where: '$columnId = ?', whereArgs: [doc.id]);
  }

  Future close() async => db.close();
}
