import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:requests/requests.dart';
import 'package:steel_crypt/steel_crypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';

enum REQUEST_RESULT {
  SUCCESS,
  FAILED,
  AUTH_FAIL,
  DOMAIN_NOT_ACCESIBLE,
  SERVER_SIDE_ERROR
}
const String SERVER_SALT = "8982@!s@%J";
const String CLIENT_SALT = "9#G68*6&e%";
const IV =
    "yLGdF7DQg24QwT0X9mvjKg=="; //b64 encoded IV generated with keyGen.genDart(len:16);

var keyGen = CryptKey();
var hasher = HashCrypt(algo: HashAlgo.Sha_256);

void storeData(String appUrl, String encryptedHello) async {
  print(encryptedHello);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString("appUrl", appUrl);
  prefs.setString("encryptedHello", encryptedHello);
}

Future<Map<String, String>> getLoginInfo() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String appUrl = prefs.getString("appUrl");
  String encryptedHello = prefs.getString("encryptedHello");

  return {"appUrl": appUrl, "encryptedHello": encryptedHello};
}

String genServerPassword(String password) {
  return hasher.hash(inp: password + SERVER_SALT);
}

String genClientPassword(String password) {
  return hasher.hash(inp: password + CLIENT_SALT);
}

Future<REQUEST_RESULT> login(
    String urlPrefix, String mailId, String password) async {
  try {
    var response = await Requests.post(urlPrefix + "/auth/login",
        body: {"email": mailId, "password": genServerPassword(password)},
        timeoutSeconds: 5,
        verify: false);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseBody = jsonDecode(response.content());
      if (responseBody["msg"] == "OK" ||
          responseBody["msg"] == "ALREADY_LOGGED_IN") {
        print(responseBody["msg"]);
        return REQUEST_RESULT.SUCCESS;
      } else {
        return REQUEST_RESULT.FAILED;
      }
    } else {
      return REQUEST_RESULT.SERVER_SIDE_ERROR;
    }
  } on SocketException {
    return REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE;
  }
}

String b64encode(String inp) {
  return base64.encode(utf8.encode(inp));
}

String b64decode(String inp) {
  if (inp == null) {
    return null;
  }
  return utf8.decode(base64.decode(inp));
}

String encrypt({@required String body, @required String password}) {
  /*
  AES CTR 256bit was chose because documents will be more than 256bits in size and
  CTR is the best approach for the same

  We cannot keep different IV for encryption and decryption , this might decrease
  the strength by a bit

  Investigation for better approaches required
  */
  String out = AesCrypt(padding: PaddingAES.pkcs7, key: password)
      .ctr
      .encrypt(inp: body, iv: IV);
  return out;
}

String decrypt({@required String body, @required String password}) {
  try {
    if (body == null || password == null) {
      return null;
    }
    String out = AesCrypt(padding: PaddingAES.pkcs7, key: password)
        .ctr
        .decrypt(enc: body, iv: IV);
    return out;
  } on FormatException {
    return null;
  }
}

Future<REQUEST_RESULT> create_account(
    String urlPrefix, String mailId, String password) async {
  try {
    var encryptionKey = keyGen.genFortuna(
        len:
            32); //Strongly generated random AES 256bit encryption key b64 format

    var encryptedEncryptionKey =
        encrypt(body: encryptionKey, password: genClientPassword(password));

    var response = await Requests.post(urlPrefix + "/auth/register",
        body: {
          "email": mailId,
          "password": genServerPassword(password),
          "encryptedEncryptionKey": encryptedEncryptionKey
        },
        timeoutSeconds: 5,
        verify: false);

    if (response.statusCode == 200) {
      Map<String, dynamic> responseBody = jsonDecode(response.content());
      if (responseBody["msg"] == "OK") {
        print(responseBody["msg"]);
        return REQUEST_RESULT.SUCCESS;
      } else {
        return REQUEST_RESULT.FAILED;
      }
    } else {
      return REQUEST_RESULT.SERVER_SIDE_ERROR;
    }
  } on SocketException {
    return REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE;
  }
}

class ResultWithBody {
  List<dynamic> body;
  REQUEST_RESULT result;
  ResultWithBody({@required this.body, @required this.result});
}

Future<ResultWithBody> getUpdatedList(
    {@required String urlPrefix, @required int lastUpdateTime}) async {
  try {
    var response = await Requests.post(
        urlPrefix + "/userDocs/newDocsSince/" + lastUpdateTime.toString(),
        verify: false);
    print(response.content());
    if (response.statusCode == 200) {
      return ResultWithBody(
          body: response.json()["body"].toList(),
          result: REQUEST_RESULT.SUCCESS);
    } else if (response.statusCode == 401) {
      return ResultWithBody(body: null, result: REQUEST_RESULT.AUTH_FAIL);
    } else {
      return ResultWithBody(
          body: null, result: REQUEST_RESULT.SERVER_SIDE_ERROR);
    }
  } on SocketException {
    return ResultWithBody(
        body: null, result: REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE);
  }
}

Future<REQUEST_RESULT> addOrUpdateDoc(
    {@required String urlPrefix, @required EncryptedDoc doc}) async {
  try {
    var response = await Requests.post(urlPrefix + "/userDocs/addOrUpdateDoc",
        body: {
          "domainname": doc.domainname,
          "credentials": doc.doc,
        },
        verify: false);
    if (response.statusCode == 200) {
      return REQUEST_RESULT.SUCCESS;
    } else {
      return REQUEST_RESULT.AUTH_FAIL;
    }
  } on SocketException {
    return REQUEST_RESULT.SERVER_SIDE_ERROR;
  }
}
