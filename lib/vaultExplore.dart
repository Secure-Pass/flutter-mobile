import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'db.dart';
import 'constants.dart';
import 'requests.dart';
import 'dart:convert';
import 'package:fuzzy/fuzzy.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:toast/toast.dart';

VaultHandler vault = null;

class VaultExplorer extends StatefulWidget {
  String appUrl;
  String password;

  VaultExplorer({@required this.appUrl, @required this.password});

  @override
  _VaultExplorerState createState() => _VaultExplorerState();
}

class _VaultExplorerState extends State<VaultExplorer> {
  bool syncingDb = true;
  REQUEST_RESULT dbSyncResult;
  BuildContext widgetContext, dialogBoxContext;

  List<DecryptedDoc> decryptedDocs = [];
  Fuzzy domainNamesFuzzy;
  bool showDBViewOverride = false;
  bool searchView = false;
  String encryptionKey = "";

  final GlobalKey<FormState> dialogBoxKey = GlobalKey<FormState>();

  Future<void> syncVault() async {
    int i = 2; //retrie count
    setState(() {
      showDBViewOverride = false;
    });
    setState(() {
      syncingDb = true;
    });
    while (i > 0) {
      await Future.delayed(Duration(milliseconds: 500));

      dbSyncResult = await vault.syncVault(appUrl: widget.appUrl);

      encryptionKey = decrypt(
          body: await vault.getEncryptedEncryptionKey(),
          password: genClientPassword(widget.password));

      decryptedDocs = await vault.getDecrypteDocs(widget.password);
      domainNamesFuzzy = Fuzzy(decryptedDocs.map((e) => e.domainname).toList());
      if (encryptionKey == null || decryptedDocs == null) {
        i -= 1;
        print("Initiating retries");
        //TODO : very rarely db does not function on starting with onCreate , so vault is closed and opened again as a fix , but need to investigate the source of the problem
        await vault.close();
        await vault.open();
        if (i == 0) {
          //If probelm still persists after vault refresh , then it is considered as a change in encryptionKey
          await storeData(null, null);
          Navigator.pop(widgetContext);
        }
      } else {
        break;
      }
    }
    setState(() {
      syncingDb = false;
    });
  }

  void initState() {
    super.initState();
    vault = VaultHandler();
    Future.delayed(Duration(seconds: 1), () async {
      vault = VaultHandler();
      await vault.open();
      await syncVault();
    });
  }

  void dispose() {
    vault.close();
    super.dispose();
  }

  Future<REQUEST_RESULT> showAddCredentialDialog(BuildContext context) async {
    return await showDialog(
        context: context,
        builder: (context) {
          String warning = "";
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              content: Form(
                  key: dialogBoxKey,
                  child: AddCredentialView(
                      decryptedDocs: decryptedDocs,
                      encryptionKey: encryptionKey,
                      appUrl: widget.appUrl,
                      domainNamesFuzzy: domainNamesFuzzy,
                      onSuccess: () {
                        Navigator.pop(context);
                        syncVault();
                      })),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    Map<REQUEST_RESULT, Widget> syncResultScreens = {
      REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Domain not accessible",
              style: titleStyle,
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              'Check your internent connection',
              style: subtitleStyle,
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 10,
            ),
            CustomButton(
              icon: Icons.sync,
              label: "Try Again",
              labelStyle: bigTextButtonStyle,
              onTap: () {
                syncVault();
              },
            ),
            SizedBox(
              height: 10,
            ),
            CustomButton(
                icon: Icons.cloud_off,
                label: "Proceed Offline",
                bgcolor: Colors.red,
                labelStyle: bigTextButtonStyle,
                onTap: () {
                  setState(() {
                    showDBViewOverride = true;
                  });
                }),
          ],
        ),
      ),
      REQUEST_RESULT.SERVER_SIDE_ERROR: Center(
        child: Text(
          "Server Side Error",
          style: subtitleStyle,
        ),
      ),
      REQUEST_RESULT.AUTH_FAIL: Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Login Expired , login again",
            style: titleStyle,
          ),
          SizedBox(
            height: 10,
          ),
          CustomButton(
              label: "Login Again",
              labelStyle: bigTextButtonStyle,
              onTap: () async {
                await storeData(null, null);
                Navigator.pop(widgetContext);
              })
        ],
      )),
      REQUEST_RESULT.SUCCESS: Scaffold(
          appBar: AppBar(
              leading: InkWell(
                  child: Icon((searchView) ? Icons.arrow_back : Icons.search),
                  onTap: () {
                    setState(() {
                      searchView = !searchView;
                    });
                  }),
              title: (!searchView) ? Text("My Vault") : TextField(),
              actions: [
                InkWell(
                  child: Icon(Icons.sync),
                  onTap: () {
                    setState(() {
                      showDBViewOverride = false;
                    });
                    syncVault();
                  },
                )
              ]),
          body: (decryptedDocs.length == 0)
              ? Center(
                  child: Text(
                  "Zero Credentials Stored , Add Some",
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ))
              : ListView.separated(
                  padding: EdgeInsets.all(20),
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                        child: ListTile(
                      leading: Image.network(
                          "https://icons.bitwarden.net/${decryptedDocs[index].domainname}/icon.png"),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 15,
                          ),
                          Text(
                            decryptedDocs[index].domainname,
                            style: GoogleFonts.ubuntuMono(
                                textStyle: subtitleStyle),
                          ),
                          SizedBox(
                            height: 15,
                          )
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: decryptedDocs[index].doc.keys.map((key) {
                          return Column(children: [
                            Row(
                              children: [
                                Expanded(
                                    flex: 4,
                                    child: InkWell(
                                      child: Text(key,
                                          softWrap: false,
                                          overflow: TextOverflow.fade,
                                          style: GoogleFonts.sourceCodePro(
                                              textStyle: credentialStyle)),
                                      onTap: () {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                content: UserNamePasswordView(
                                                    username: key,
                                                    password:
                                                        decryptedDocs[index]
                                                                .doc[key]
                                                            ['password']),
                                              );
                                            });
                                      },
                                    )),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                      icon: Icon(Icons.account_circle),
                                      onPressed: () {
                                        copyToClipBoard(
                                            context: context,
                                            label: "username",
                                            data: key);
                                      }),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                      icon: Icon(Icons.vpn_key_sharp),
                                      onPressed: () {
                                        copyToClipBoard(
                                            context: context,
                                            label: "password",
                                            data: decryptedDocs[index].doc[key]
                                                ['password']);
                                      }),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                      icon: Icon(Icons.create),
                                      onPressed: () {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                content: EditCredentialView(
                                                    appUrl: widget.appUrl,
                                                    username: key,
                                                    encryptionKey:
                                                        encryptionKey,
                                                    targetDecryptedDoc:
                                                        decryptedDocs[index],
                                                    onSuccess: () {
                                                      Navigator.pop(context);
                                                      syncVault();
                                                    }),
                                              );
                                            });
                                      }),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 5,
                            )
                          ]);
                        }).toList(),
                      ),
                    ));
                  },
                  separatorBuilder: (BuildContext context, int index) =>
                      SizedBox(),
                  itemCount: decryptedDocs.length)),
    };

    widgetContext = context; //for onSuccess Navigation

    return Scaffold(
      body: (vault == null)
          ? Center(child: loadingBetweenScreensInverted)
          : (syncingDb)
              ? syncingDBScreen
              : (showDBViewOverride)
                  ? syncResultScreens[REQUEST_RESULT.SUCCESS]
                  : syncResultScreens[dbSyncResult],
      floatingActionButton: (dbSyncResult == REQUEST_RESULT.SUCCESS)
          ? FloatingActionButton(
              onPressed: () {
                showAddCredentialDialog(context); //Popup dialog boxes here
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}

void copyToClipBoard(
    {@required BuildContext context,
    @required String label,
    @required String data}) {
  Clipboard.setData(ClipboardData(text: data));
  Toast.show(
    "$label copied to clipboard",
    context,
    duration: Toast.LENGTH_LONG,
    gravity: Toast.BOTTOM,
  );
}

class UserNamePasswordView extends StatefulWidget {
  String username, password;
  UserNamePasswordView({@required this.username, @required this.password});

  @override
  _UserNamePasswordViewState createState() => _UserNamePasswordViewState();
}

class _UserNamePasswordViewState extends State<UserNamePasswordView> {
  bool showpassword = false;
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 15,
            ),
            Row(
              children: [
                Icon(Icons.account_circle),
                SizedBox(
                  width: 15,
                ),
                Expanded(
                    flex: 5,
                    child: Text(
                      widget.username,
                      style: GoogleFonts.sourceCodePro(
                          textStyle: credentialStyle.copyWith(fontSize: 20)),
                    )),
                Expanded(
                  flex: 1,
                  child: IconButton(
                    icon: Icon(Icons.copy),
                    onPressed: () {
                      copyToClipBoard(
                          context: context,
                          label: 'username',
                          data: widget.username);
                    },
                  ),
                )
              ],
            ),
            Divider(),
            Row(children: [
              Icon(Icons.vpn_key),
              SizedBox(
                width: 15,
              ),
              Expanded(
                flex: 4,
                child: Text(
                  (showpassword) ? widget.password : "xxxxx",
                  style: GoogleFonts.sourceCodePro().copyWith(fontSize: 20),
                ),
              ),
              Expanded(
                  flex: 1,
                  child: IconButton(
                    icon: Icon(
                      (showpassword) ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showpassword = !showpassword;
                      });
                    },
                  )),
              Expanded(
                  flex: 1,
                  child: IconButton(
                    icon: Icon(Icons.copy),
                    onPressed: () {
                      copyToClipBoard(
                          context: context,
                          label: 'password',
                          data: widget.password);
                    },
                  ))
            ])
          ],
        ),
        Positioned(
          child: CircleAvatar(
            child: Transform.rotate(
              angle: 11 / 14, //pi/4 radians i.e 45 degree rotation
              child: Icon(
                Icons.vpn_key,
                size: 40,
              ),
            ),
            radius: 40,
          ),
          top: -60,
        )
      ],
    );
  }
}

class EditCredentialView extends StatefulWidget {
  String appUrl;
  DecryptedDoc targetDecryptedDoc;
  String encryptionKey;
  String username;
  Function onSuccess;
  EditCredentialView(
      {@required this.appUrl,
      @required this.encryptionKey,
      @required this.username,
      @required this.targetDecryptedDoc,
      @required this.onSuccess});

  @override
  _EditCredentialViewState createState() => _EditCredentialViewState();
}

class _EditCredentialViewState extends State<EditCredentialView> {
  String password;
  String warning = "";
  TextEditingController passwordInp;

  @override
  void initState() {
    super.initState();
    print("initState");
    password = widget.targetDecryptedDoc.doc[widget.username]['password'];
    print(password);
    passwordInp = TextEditingController(text: password);
    print(passwordInp.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Edit Credentials",
            style: titleStyle,
          ),
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                    ),
                    Icon(Icons.perm_identity),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(child: Center(child: Text(widget.username)))
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: passwordInp,
                  onChanged: (value) {
                    password = value;
                  },
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      hintText: "Password", prefixIcon: Icon(Icons.vpn_key)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
          ),
          (warning == "")
              ? SizedBox()
              : Column(
                  children: [
                    Text(
                      warning,
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(
                      height: 20,
                    )
                  ],
                ),
          CustomButton(
            label: "Update Credentials",
            onTap: () async {
              if (password == "") {
                setState(() {
                  warning = "**ALL FIELD ARE REQUIRED**";
                });
              } else {
                setState(() {
                  warning = "";
                });
                widget.targetDecryptedDoc.doc[widget.username]['password'] =
                    password;

                String b64form =
                    b64encode(jsonEncode(widget.targetDecryptedDoc.doc));
                String encryptedCredential =
                    encrypt(body: b64form, password: widget.encryptionKey);
                EncryptedDoc encryptedDoc = EncryptedDoc(
                  domainname: widget.targetDecryptedDoc.domainname,
                  doc: encryptedCredential,
                );
                print("sending request");
                REQUEST_RESULT result = await addOrUpdateDoc(
                    urlPrefix: widget.appUrl, doc: encryptedDoc);
                if (result == REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE) {
                  setState(() {
                    warning = "Site not reachable , try again alter";
                  });
                } else if (result == REQUEST_RESULT.FAILED) {
                  setState(() {
                    warning = "Login Expiredm try logging out";
                  });
                } else if (result == REQUEST_RESULT.SUCCESS) {
                  widget.onSuccess();
                }
              }
            },
          ),
          //TODO:Add Deletion Operation
        ],
      ),
    );
  }
}

class AddCredentialView extends StatefulWidget {
  String appUrl;
  List<DecryptedDoc> decryptedDocs;
  Fuzzy domainNamesFuzzy;
  String encryptionKey;
  Function onSuccess;
  AddCredentialView(
      {@required this.appUrl,
      @required this.decryptedDocs,
      @required this.domainNamesFuzzy,
      @required this.encryptionKey,
      @required this.onSuccess});

  @override
  _AddCredentialViewState createState() => _AddCredentialViewState();
}

class _AddCredentialViewState extends State<AddCredentialView> {
  String domainname = "";
  String username = "";
  String password = "";
  String warning = "";
  TextEditingController domainnameInp = TextEditingController();
  TextEditingController usernameInp = TextEditingController();
  TextEditingController passwordInp = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Add Credentials",
            style: titleStyle,
          ),
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                TypeAheadField(
                    textFieldConfiguration: TextFieldConfiguration(
                        decoration: InputDecoration(
                            hintText: "Domain Name",
                            prefixIcon: Icon(Icons.language)),
                        controller: domainnameInp,
                        autofocus: true,
                        onChanged: (value) {
                          domainname = value;
                        },
                        textAlign: TextAlign.center),
                    suggestionsCallback: (pattern) {
                      var results = widget.domainNamesFuzzy.search(pattern);
                      if (results.isEmpty) {
                        return [];
                      } else {
                        if (results.first.score > 0.0) {
                          return [results.first.item];
                        }
                        return [];
                      }
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(title: Text(suggestion));
                    },
                    onSuggestionSelected: (suggestion) {
                      domainnameInp.text = suggestion;
                      domainname = suggestion;
                    }),
                SizedBox(
                  height: 10,
                ),
                CustomTextField(
                  label: "Username",
                  prefixIcon: Icon(Icons.perm_identity),
                  controller: usernameInp,
                  onChanged: (value) {
                    username = value;
                  },
                ),
                SizedBox(
                  height: 10,
                ),
                CustomTextField(
                  label: "Password",
                  prefixIcon: Icon(Icons.vpn_key),
                  controller: passwordInp,
                  onChanged: (value) {
                    password = value;
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
          ),
          (warning == "")
              ? SizedBox()
              : Column(
                  children: [
                    Text(
                      warning,
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(
                      height: 20,
                    )
                  ],
                ),
          CustomButton(
            label: "Add Credentials",
            onTap: () async {
              if (domainname == "" || username == "" || password == "") {
                setState(() {
                  warning = "**ALL FIELD ARE REQUIRED**";
                });
              } else {
                setState(() {
                  warning = "";
                });
                int docIndex = widget.domainNamesFuzzy.list.indexOf(domainname);
                Map<String, dynamic> credential;
                if (docIndex == -1) {
                  credential = {
                    username: {"password": password}
                  };
                } else {
                  credential = widget.decryptedDocs[docIndex].doc;
                  credential[username] = {"password": password};
                  print(credential);
                }
                print(jsonEncode(credential));
                String b64form = b64encode(jsonEncode(credential));
                String encryptedCredential =
                    encrypt(body: b64form, password: widget.encryptionKey);
                EncryptedDoc encryptedDoc = EncryptedDoc(
                  domainname: domainname,
                  doc: encryptedCredential,
                );
                print("sending request");
                REQUEST_RESULT result = await addOrUpdateDoc(
                    urlPrefix: widget.appUrl, doc: encryptedDoc);
                if (result == REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE) {
                  setState(() {
                    warning = "Site not reachable , try again alter";
                  });
                } else if (result == REQUEST_RESULT.FAILED) {
                  setState(() {
                    warning = "Login Expiredm try logging out";
                  });
                }
                widget.onSuccess();
              }
            },
          )
        ],
      ),
    );
  }
}
