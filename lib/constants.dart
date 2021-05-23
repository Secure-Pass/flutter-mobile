import 'package:flutter/material.dart';

Widget syncingDBScreen = Center(
    child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    loadingBetweenScreensInverted,
    SizedBox(
      height: 25,
    ),
    Text(
      "Syncing DB\nPlease Wait",
      style: titleStyle,
    ),
  ],
));

Positioned logoPopupForStack = Positioned(
  top: -25,
  child: Container(
    padding: EdgeInsets.all(5),
    child: Image.asset("logo.png"),
    decoration: curvedContainerDecoration.copyWith(boxShadow: [
      BoxShadow(color: Colors.grey, spreadRadius: 2, blurRadius: 4)
    ]),
  ),
);

TextStyle titleStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 30);
TextStyle subtitleStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 25);
TextStyle bigTextButtonStyle =
    TextStyle(fontSize: 25, fontWeight: FontWeight.w400);
TextStyle credentialStyle =
    TextStyle(fontWeight: FontWeight.w600, fontSize: 20, fontFamily: 'roboto');

BoxDecoration curvedContainerDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(5)),
);

BoxDecoration curvedContainerDecorationWithShadow =
    curvedContainerDecoration.copyWith(boxShadow: [
  BoxShadow(
      color: Colors.grey.withOpacity(0.1),
      spreadRadius: 3,
      blurRadius: 3,
      offset: Offset(3, 3))
]);

var loadingBetweenScreens = SizedBox(
    width: 100,
    height: 100,
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      strokeWidth: 10,
    ));

var loadingBetweenScreensInverted = SizedBox(
    width: 100,
    height: 100,
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade900),
      strokeWidth: 10,
    ));

class CustomTextField extends StatelessWidget {
  String label;
  TextEditingController controller;
  bool hideText, letterSpacing;
  Icon prefixIcon;
  Function(String) onChanged;
  CustomTextField({
    @required this.label,
    @required this.controller,
    @required this.onChanged,
    this.hideText,
    this.letterSpacing,
    this.prefixIcon,
  }) {
    if (this.hideText == null) {
      this.hideText = false;
    }
    if (this.letterSpacing == null) {
      this.letterSpacing = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    return TextField(
      textAlign: TextAlign.center,
      controller: null,
      obscureText: this.hideText,
      onChanged: this.onChanged,
      style: (this.letterSpacing) ? TextStyle(letterSpacing: 6) : null,
      decoration: InputDecoration(
        hintText: this.label,
        prefixIcon: this.prefixIcon,
        /*focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        labelText: this.label,
        labelStyle: TextStyle(color: Colors.black)*/
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  String label;
  Function onTap;
  Color bgcolor, labelColor;
  TextStyle labelStyle;
  IconData icon;

  CustomButton(
      {@required this.label,
      @required this.onTap,
      this.bgcolor,
      this.labelStyle,
      this.labelColor,
      this.icon}) {
    if (this.bgcolor == null) {
      this.bgcolor = Colors.green.shade700;
    }
    if (this.labelStyle == null) {
      this.labelStyle = TextStyle();
    }
    if (this.labelColor == null) {
      this.labelColor = Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: this.onTap,
      child: Container(
          padding: EdgeInsets.all(8),
          decoration: curvedContainerDecoration.copyWith(color: bgcolor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              (this.icon == null)
                  ? SizedBox()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          this.icon,
                          color: Colors.white,
                        ),
                        SizedBox(
                          width: 5,
                        )
                      ],
                    ),
              Text(
                this.label,
                style: this.labelStyle.copyWith(color: this.labelColor),
              ),
            ],
          )),
    );
  }
}
