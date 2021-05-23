import 'dart:convert';
import 'vaultExplore.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'requests.dart'; //Contains all the server communication and encryption related code
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  Map<String, String> credentialData = null;

  bool runAnimation = true;
  bool runStream = true;

  bool animationHelper = false;
  Duration animationDuration = Duration(seconds: 2);

  Future startAnimation() async {
    while (runAnimation) {
      await Future.delayed(animationDuration);
      setState(() {
        animationHelper = !animationHelper;
      });
    }
  }

  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      while (runStream) {
        await Future.delayed(Duration(seconds: 1));
        var temp = await getLoginInfo();
        setState(() {
          credentialData = temp;
        });
      }
    });
    startAnimation();
  }

  void dispose() {
    runAnimation = false;
    runStream = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.ease,
        child: Center(
          child: (credentialData == null)
              ? loadingBetweenScreens
              : (credentialData["appUrl"] == null)
                  ? signup_in()
                  : logged_in_flow(),
        ),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: (animationHelper)
                    ? [Colors.green.shade900, Colors.green.shade50]
                    : [Colors.green.shade50, Colors.green.shade900])),
      ),
    );
  }
}

class signup_in extends StatefulWidget {
  signup_in({Key key}) : super(key: key);

  @override
  _signup_inState createState() => _signup_inState();
}

class _signup_inState extends State<signup_in> {
  TextEditingController mailIdInp, passwordInp, password2Inp, urlInp;
  String mailId = "";
  String password = "";
  String password2 = "";
  String Url = "https://10.0.2.3:5000";

  bool processingRequest = false;
  bool showSignInPage = true;
  String warning = "";

  bool wiggleHelper = false;
  double wiggleDuration = 1.5;

  void wiggleNow() async {
    double i = wiggleDuration / 0.1;
    while (i > 0) {
      setState(() {
        wiggleHelper = true;
      });
      await Future.delayed(Duration(milliseconds: 50));
      setState(() {
        wiggleHelper = false;
      });
      await Future.delayed(Duration(milliseconds: 50));
      i -= 1;
    }
  }

  void updateWarning(String warn) {
    setState(() {
      warning = warn;
    });
    wiggleNow();
  }

  void initState() {
    super.initState();

    mailIdInp = TextEditingController();
    passwordInp = TextEditingController();
    password2Inp = TextEditingController();
    urlInp = TextEditingController(text: "https://10.0.2.3:5000");
  }

  void dispose() {
    mailIdInp.dispose();
    password2Inp.dispose();
    passwordInp.dispose();
    urlInp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: (MediaQuery.of(context).size.width > 600)
              ? 400
              : MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 25,
              ),
              Text(
                (showSignInPage) ? "Account Login" : "Create Account",
                style: titleStyle,
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text((showSignInPage)
                      ? "Dont have any account?  "
                      : "Already have an account?  "),
                  InkWell(
                    child: Text(
                      (showSignInPage) ? "Sign Up" : "Login",
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 20),
                    ),
                    onTap: () {
                      setState(() {
                        showSignInPage = !showSignInPage;
                      });

                      if (!showSignInPage) {
                        updateWarning("**Please set a strong password**");
                      } else {
                        updateWarning(" ");
                      }
                      password2 = ""; //Clearing re-type password buffer
                    },
                  )
                ],
              ),
              SizedBox(
                height: 20,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    TextField(
                      controller: urlInp,
                      onChanged: (value) {
                        Url = value;
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: "Url", prefixIcon: Icon(Icons.language)),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    TextField(
                      controller: mailIdInp,
                      onChanged: (value) {
                        mailId = value;
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: "Email ID",
                          prefixIcon: Icon(Icons.alternate_email)),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    TextField(
                      controller: passwordInp,
                      onChanged: (value) {
                        password = value;
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(Icons.vpn_key)),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    (showSignInPage)
                        ? SizedBox()
                        : Column(
                            children: [
                              TextField(
                                controller: password2Inp,
                                onChanged: (value) {
                                  password2 = value;
                                },
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                    hintText: "Re-Type Password",
                                    prefixIcon: Icon(Icons.vpn_key)),
                              ),
                              SizedBox(
                                height: 25,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              (warning == "")
                  ? SizedBox()
                  : Column(
                      children: [
                        Text(
                          (wiggleHelper) ? warning : "  " + warning,
                          style: TextStyle(color: Colors.red),
                        ),
                        SizedBox(
                          height: 10,
                        )
                      ],
                    ),
              (processingRequest)
                  ? CircularProgressIndicator()
                  : CustomButton(
                      label: (showSignInPage) ? "Sign In" : "Create Account",
                      //bgcolor: Colors.blue.shade900,
                      labelStyle: bigTextButtonStyle,
                      onTap: () async {
                        if (showSignInPage) {
                          if (Url == "" || mailId == "" || password == "") {
                            updateWarning("**Enter All the Fields**");
                          } else {
                            setState(() {
                              processingRequest = true;
                            });

                            REQUEST_RESULT result =
                                await login(Url, mailId, password);

                            var encryptedHello = encrypt(
                                body: b64encode("hello"),
                                password: genClientPassword(password));
                            print(genClientPassword(password));
                            print(encryptedHello);
                            setState(() {
                              processingRequest = false;
                            });

                            if (result == REQUEST_RESULT.SUCCESS) {
                              updateWarning("Success");
                              storeData(Url,
                                  encryptedHello); //As soon as value is stored navigation occurs

                            } else if (result == REQUEST_RESULT.FAILED) {
                              updateWarning("**Wrong mail or password**");
                            } else if (result ==
                                REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE) {
                              updateWarning("**Not able to access server**");
                            } else {
                              updateWarning("**Server Side Error**");
                            }
                          }
                        } else {
                          if (Url == "" ||
                              mailId == "" ||
                              password == "" ||
                              password2 == "") {
                            updateWarning("**Enter All the Fields**");
                          } else if (password != password2) {
                            updateWarning("**Passwords dont match**");
                          } else {
                            setState(() {
                              processingRequest = true;
                            });

                            REQUEST_RESULT result =
                                await create_account(Url, mailId, password);

                            setState(() {
                              processingRequest = false;
                            });

                            if (result == REQUEST_RESULT.SUCCESS) {
                              updateWarning(
                                  "**ACCOUNT CREATED , Redirecting to Login page in 10 sec**");
                              //Redirection in 5seconds
                              Future.delayed(Duration(seconds: 10), () {
                                setState(() {
                                  showSignInPage = true;
                                });
                                updateWarning("**Login with new account**");
                              });
                            } else if (result == REQUEST_RESULT.FAILED) {
                              updateWarning("**Mail id already registered**");
                            } else if (result ==
                                REQUEST_RESULT.DOMAIN_NOT_ACCESIBLE) {
                              updateWarning("**Server not accessible**");
                            } else {
                              updateWarning("**Server Side Error");
                            }
                          }
                        }
                      })
            ]),
          ),
          padding: EdgeInsets.all(20),
          decoration: curvedContainerDecoration,
        ),
        logoPopupForStack
      ],
    );
  }
}

class logged_in_flow extends StatefulWidget {
  logged_in_flow({Key key}) : super(key: key);

  @override
  _logged_in_flowState createState() => _logged_in_flowState();
}

class _logged_in_flowState extends State<logged_in_flow> {
  String password = "";
  Map<String, String> credentialData = null;
  TextEditingController passwordInp;

  String warning = "";

  bool wiggleHelper = false;
  double wiggleDuration = 1.5;

  void wiggleNow() async {
    double i = wiggleDuration / 0.1;
    while (i > 0) {
      setState(() {
        wiggleHelper = true;
      });
      await Future.delayed(Duration(milliseconds: 50));
      setState(() {
        wiggleHelper = false;
      });
      await Future.delayed(Duration(milliseconds: 50));
      i -= 1;
    }
  }

  void updateWarning(String warn) {
    setState(() {
      warning = warn;
    });
    wiggleNow();
  }

  void initState() {
    super.initState();
    passwordInp = TextEditingController();

    Future.delayed(Duration(seconds: 1), () async {
      var temp = await getLoginInfo();
      setState(() {
        credentialData = temp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return (credentialData == null)
        ? loadingBetweenScreens
        : Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.75,
                padding: EdgeInsets.all(20),
                decoration: curvedContainerDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 30,
                    ),
                    Text("Unlock Vault", style: titleStyle),
                    SizedBox(
                      height: 15,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: CustomTextField(
                          hideText: true,
                          label: "Password",
                          letterSpacing: true,
                          controller: passwordInp,
                          onChanged: (value) {
                            password = value;
                          }),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    (warning == "")
                        ? SizedBox()
                        : Column(
                            children: [
                              Text(
                                (wiggleHelper) ? warning : "  " + warning,
                                style: TextStyle(color: Colors.red),
                              ),
                              SizedBox(
                                height: 10,
                              )
                            ],
                          ),
                    CustomButton(
                      label: "Unlock",
                      icon: Icons.lock_open,
                      onTap: () {
                        var encryptedHello = credentialData["encryptedHello"];
                        print(encryptedHello);
                        print(base64.decode(encryptedHello));
                        var decrypted = decrypt(
                            body: encryptedHello,
                            password: genClientPassword(password));
                        bool isMatch = ("hello" == b64decode(decrypted));
                        if (!isMatch) {
                          updateWarning("**Wrong Password**");
                        } else {
                          updateWarning("**Success Password**");
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => VaultExplorer(
                                        appUrl: credentialData["appUrl"],
                                        password: password,
                                      )));
                        }
                      },
                      labelStyle: bigTextButtonStyle,
                    )
                  ],
                ),
              ),
              logoPopupForStack
            ],
          );
  }
}
