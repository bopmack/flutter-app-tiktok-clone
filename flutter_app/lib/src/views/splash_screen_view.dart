import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:liquid_progress_indicator_ns/liquid_progress_indicator.dart';
import 'package:mvc_pattern/mvc_pattern.dart';

import '../controllers/splash_screen_controller.dart';
import '../repositories/settings_repository.dart' as settingRepo;

class SplashScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return SplashScreenState();
  }
}

class SplashScreenState extends StateMVC<SplashScreen> with WidgetsBindingObserver {
  String dataShared = "No Data";
  SplashScreenController _con = SplashScreenController();
  late BuildContext context;
  double _height = 0.0;
  double _width = 0.0;

  SplashScreenState() : super(SplashScreenController()) {
    _con = SplashScreenController();
  }

  @override
  void initState() {
    _con.initializing();
    super.initState();
  }

  DateTime currentBackPressTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    _height = MediaQuery.of(context).size.height;
    _width = MediaQuery.of(context).size.width;
    setState(() => this.context = context);
    return Scaffold(
      backgroundColor: settingRepo.setting.value.bgColor,
      body: WillPopScope(
        onWillPop: () {
          DateTime now = DateTime.now();
          // Navigator.pop(context);
          if (currentBackPressTime == null || now.difference(currentBackPressTime) > Duration(seconds: 2)) {
            currentBackPressTime = now;
            Fluttertoast.showToast(msg: "Tap again to exit an app.");
            return Future.value(false);
          }
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          return Future.value(true);
        },
        child: ValueListenableBuilder(
          valueListenable: _con.loadingPercent,
          builder: (context, double percent, _) => Container(
            height: _height,
            width: _width,
            color: settingRepo.setting.value.bgColor,
            padding: EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    color: settingRepo.setting.value.bgColor,
                    height: 40,
                    child: LiquidLinearProgressIndicator(
                      value: percent / 100,
                      valueColor: AlwaysStoppedAnimation(settingRepo.setting.value.accentColor!),
                      backgroundColor: settingRepo.setting.value.bgColor,
                      borderColor: settingRepo.setting.value.textColor!,
                      borderWidth: 5.0,
                      borderRadius: 12.0,
                      direction: Axis.horizontal,
                      center: Text(
                        percent.toString() + "%",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: settingRepo.setting.value.textColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "Loading...",
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: settingRepo.setting.value.textColor,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
