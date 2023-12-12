import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import "package:velocity_x/velocity_x.dart";

import '../helpers/app_config.dart' as config;
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/video_repository.dart' as videoRepo;

class InternetPage extends StatefulWidget {
  InternetPage({Key? key}) : super(key: key);

  @override
  _InternetPageState createState() => _InternetPageState();
}

class _InternetPageState extends StateMVC<InternetPage> {
  @override
  void initState() {
    if (!videoRepo.homeCon.value.showFollowingPage.value) {
      if (videoRepo.homeCon.value.videoController(videoRepo.homeCon.value.swiperIndex) != null) {
        videoRepo.homeCon.value.videoController(videoRepo.homeCon.value.swiperIndex).pause();
      }
    } else {
      if (videoRepo.homeCon.value.videoController(videoRepo.homeCon.value.swiperIndex2) != null) {
        videoRepo.homeCon.value.videoController(videoRepo.homeCon.value.swiperIndex2).pause();
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        videoRepo.isOnNoInternetPage.value = false;
        videoRepo.isOnNoInternetPage.notifyListeners();
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: settingRepo.setting.value.bgColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Container(
            height: config.App(context).appHeight(100),
            width: config.App(context).appWidth(100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  "assets/icons/no-wifi.svg",
                  color: settingRepo.setting.value.iconColor,
                  width: 50,
                  height: 50,
                ),
                SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: "There is no network connection right now. check your internet connection".text.center.lineHeight(1.4).size(15).color(settingRepo.setting.value.textColor!).make().centered(),
                ),
                SizedBox(
                  height: 20,
                ),
                "Enable wifi or mobile data".text.uppercase.center.lineHeight(1.4).size(15).color(settingRepo.setting.value.textColor!).make().centered(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
