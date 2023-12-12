import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:readmore/readmore.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../helpers/app_config.dart';
import '../helpers/helper.dart';
import '../models/videos_model.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/user_repository.dart' as userRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../views/my_profile_view.dart';
import '../views/password_login_view.dart';
import '../views/user_profile_view.dart';
import 'MarqueWidget.dart';

class VideoDescription extends StatefulWidget {
  final Video video;
  final PanelController pc3;
  VideoDescription(this.video, this.pc3);
  @override
  _VideoDescriptionState createState() => _VideoDescriptionState();
}

class _VideoDescriptionState extends StateMVC<VideoDescription> {
  String username = "";
  String description = "";
  String appToken = "";
  int soundId = 0;
  int loginId = 0;
  bool isLogin = false;
  late AnimationController animationController;
  // static const double ActionWidgetSize = 60.0;
  // static const double ProfileImageSize = 50.0;

  String soundImageUrl = "";

  String profileImageUrl = "";

  bool showFollowLoader = false;
  bool isVerified = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    username = widget.video.username;
    isVerified = widget.video.isVerified;
    // isVerified = true;
    description = widget.video.description;
    profileImageUrl = widget.video.userDP;
    print("CheckVerified $username ${widget.video.isVerified};");
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }
/*
  _getSessionData() async {
    sessions.getUserInfo().then((obj) {
      setState(() {
        if (obj['user_id'] > 0) {
          isLogin = true;
          loginId = obj['user_id'];
          appToken = obj['app_token'];
        } else {}
      });
    });
  }*/

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: videoRepo.homeCon.value.descriptionHeight,
        builder: (context, double heightPercent, _) {
          return Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: App(context).appHeight(heightPercent) + MediaQuery.of(context).padding.bottom + videoRepo.homeCon.value.paddingBottom,
              ),
              padding: EdgeInsets.only(left: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () async {
                          if (!videoRepo.homeCon.value.showFollowingPage.value) {
                            videoRepo.homeCon.value.stopController(videoRepo.homeCon.value.swiperIndex);
                          } else {
                            videoRepo.homeCon.value.stopController2(videoRepo.homeCon.value.swiperIndex2);
                          }
                          videoRepo.isOnHomePage.value = false;
                          videoRepo.isOnHomePage.notifyListeners();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => widget.video.userId == userRepo.currentUser.value.userId
                                  ? MyProfileView()
                                  : UsersProfileView(
                                      userId: widget.video.userId,
                                    ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: settingRepo.setting.value.dpBorderColor!,
                            ),
                            borderRadius: BorderRadius.circular(50.0),
                          ),
                          child: profileImageUrl != ''
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50.0),
                                  child: CachedNetworkImage(
                                    imageUrl: profileImageUrl,
                                    placeholder: (context, url) => Helper.showLoaderSpinner(settingRepo.setting.value.iconColor!),
                                    height: 60.0,
                                    width: 60.0,
                                    fit: BoxFit.fitHeight,
                                    errorWidget: (a, b, c) {
                                      return Image.asset(
                                        "assets/images/video-logo.png",
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(50.0),
                                  child: Image.asset(
                                    "assets/images/splash.png",
                                    height: 40.0,
                                    width: 40.0,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          username != ''
                              ? GestureDetector(
                                  onTap: () async {
                                    /*await videoRepo.homeCon.value.videoController(videoRepo.homeCon.value.swiperIndex)?.pause();
                                await videoRepo.homeCon.value.videoController2(videoRepo.homeCon.value.swiperIndex2)?.pause();*/
                                    videoRepo.isOnHomePage.value = false;
                                    videoRepo.isOnHomePage.notifyListeners();
                                    if (!videoRepo.homeCon.value.showFollowingPage.value) {
                                      videoRepo.homeCon.value.stopController(videoRepo.homeCon.value.swiperIndex);
                                    } else {
                                      videoRepo.homeCon.value.stopController2(videoRepo.homeCon.value.swiperIndex2);
                                    }
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => widget.video.userId == userRepo.currentUser.value.userId
                                            ? MyProfileView()
                                            : UsersProfileView(
                                                userId: widget.video.userId,
                                              ),
                                      ),
                                    );
                                  },
                                  child: MarqueeWidget(
                                    child: Row(
                                      children: [
                                        Text(
                                          username,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: settingRepo.setting.value.headingColor,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 5.0,
                                        ),
                                        isVerified == true
                                            ? Icon(
                                                Icons.verified,
                                                color: Colors.blueAccent,
                                                size: 16,
                                              )
                                            : Container(),
                                        SizedBox(
                                          width: 20.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(),
                          (widget.video.userId != userRepo.currentUser.value.userId)
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ValueListenableBuilder(
                                      valueListenable: videoRepo.homeCon.value.showFollowLoader,
                                      builder: (context, bool showFollowLoading, _) {
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            showFollowLoading
                                                ? Container(
                                                    height: 25,
                                                    width: 65,
                                                    decoration: BoxDecoration(
                                                      color: settingRepo.setting.value.accentColor,
                                                      borderRadius: BorderRadius.circular(10.0),
                                                    ),
                                                    child: Center(
                                                      child: showLoaderSpinner(),
                                                    ),
                                                  )
                                                : InkWell(
                                                    onTap: () async {
                                                      if (userRepo.currentUser.value.token != "") {
                                                        if (videoRepo.homeCon.value.showFollowingPage.value) {
                                                          if (videoRepo.followingUsersVideoData.value.videos.elementAt(videoRepo.homeCon.value.showFollowingPage.value ? videoRepo.homeCon.value.swiperIndex2 : videoRepo.homeCon.value.swiperIndex).isFollowing == 0) {
                                                            videoRepo.followingUsersVideoData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex2).totalFollowers++;
                                                          } else {
                                                            videoRepo.followingUsersVideoData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex2).totalFollowers--;
                                                          }
                                                          videoRepo.followingUsersVideoData.notifyListeners();
                                                        } else {
                                                          print("videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).isFollowing ${videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).isFollowing}");
                                                          if (videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).isFollowing == 0) {
                                                            videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).isFollowing = 1;
                                                            videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).totalFollowers++;
                                                          } else {
                                                            videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).isFollowing = 0;
                                                            videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex).totalFollowers--;
                                                          }
                                                          videoRepo.videosData.notifyListeners();
                                                        }
                                                        await videoRepo.homeCon.value.followUnfollowUser(widget.video);
                                                      } else {
                                                        videoRepo.isOnHomePage.value = false;
                                                        videoRepo.isOnHomePage.notifyListeners();
                                                        if (!videoRepo.homeCon.value.showFollowingPage.value) {
                                                          videoRepo.homeCon.value.stopController(videoRepo.homeCon.value.swiperIndex);
                                                        } else {
                                                          videoRepo.homeCon.value.stopController2(videoRepo.homeCon.value.swiperIndex2);
                                                        }
                                                        Navigator.pushReplacement(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => PasswordLoginView(userId: 0),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      height: 25,
                                                      width: 65,
                                                      decoration: BoxDecoration(
                                                        color: settingRepo.setting.value.accentColor,
                                                        borderRadius: BorderRadius.circular(10.0),
                                                      ),
                                                      child: Center(
                                                        child: (!showFollowLoading)
                                                            ? videoRepo.homeCon.value.showFollowingPage.value
                                                                ? Text(
                                                                    (videoRepo.followingUsersVideoData.value.videos.elementAt(videoRepo.homeCon.value.showFollowingPage.value ? videoRepo.homeCon.value.swiperIndex2 : videoRepo.homeCon.value.swiperIndex).isFollowing == 0) ? "Follow" : "Unfollow",
                                                                    style: TextStyle(
                                                                      color: settingRepo.setting.value.buttonTextColor,
                                                                      fontWeight: FontWeight.normal,
                                                                      fontSize: 12,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    (videoRepo.videosData.value.videos.elementAt(videoRepo.homeCon.value.showFollowingPage.value ? videoRepo.homeCon.value.swiperIndex2 : videoRepo.homeCon.value.swiperIndex).isFollowing == 0) ? "Follow" : "Unfollow",
                                                                    style: TextStyle(
                                                                      color: settingRepo.setting.value.buttonTextColor,
                                                                      fontWeight: FontWeight.normal,
                                                                      fontSize: 12,
                                                                    ),
                                                                  )
                                                            : showLoaderSpinner(),
                                                      ),
                                                    ),
                                                  ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            widget.video.totalFollowers > 0
                                                ? Text(
                                                    "${Helper.formatter(widget.video.totalFollowers.toString())} " + (widget.video.totalFollowers > 1 ? "Followers" : "Follower"),
                                                    style: TextStyle(
                                                      color: settingRepo.setting.value.textColor,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : Container(),
                                            description.length > 55
                                                ? InkWell(
                                                    onTap: () {
                                                      videoRepo.homeCon.value.descriptionHeight.value = videoRepo.homeCon.value.descriptionHeight.value == 18.0 ? 40.0 : 18.0;
                                                      videoRepo.homeCon.value.descriptionHeight.notifyListeners();
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(top: 2.0, left: 3, right: 3),
                                                      child: Icon(
                                                        videoRepo.homeCon.value.descriptionHeight.value == 18.0 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                        color: settingRepo.setting.value.textColor,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  )
                                                : Container(),
                                          ],
                                        );
                                      }),
                                )
                              : Container(),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  description != ''
                      ? InkWell(
                          onTap: () {
                            if (description.length > 55) {
                              videoRepo.homeCon.value.descriptionHeight.value = /* videoRepo.homeCon.value.descriptionHeight.value == 18.0 ?*/ 40.0;
                              videoRepo.homeCon.value.descriptionHeight.notifyListeners();
                            }
                          },
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  (App(context).appHeight(heightPercent) + MediaQuery.of(context).padding.bottom + videoRepo.homeCon.value.paddingBottom) - 130 > 0 ? (App(context).appHeight(heightPercent) + MediaQuery.of(context).padding.bottom + videoRepo.homeCon.value.paddingBottom) - 130 : 35,
                            ),
                            child: new SingleChildScrollView(
                                scrollDirection: Axis.vertical, //.horizontal
                                child: /*Text(
                                "$description",
                                style: TextStyle(
                                  color: settingRepo.setting.value.textColor,
                                ),
                              ),*/
                                    ReadMoreText(
                                  "$description",
                                  trimLines: 2,
                                  colorClickableText: Colors.pink,
                                  trimMode: TrimMode.Line,
                                  trimCollapsedText: '...Show more',
                                  trimExpandedText: ' show less',
                                )),
                          ),
                        )
                      : Container(),
                  // SizedBox(
                  //   height: 30.0,
                  // ),
                ],
              ),
            ),
          );
        });
  }

/*  Widget _getMusicPlayerAction() {
    return GestureDetector(
      onTap: () {
        print(soundId);
        (isLogin)
            ? Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoRecorder(soundId),
                ),
              )
            : widget.pc3.open();
      },
      child: RotationTransition(
        turns: Tween(begin: 0.0, end: 1.0).animate(animationController),
        child: Container(
          margin: EdgeInsets.only(top: 10.0),
          width: ActionWidgetSize,
          height: ActionWidgetSize,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.0),
                height: ProfileImageSize,
                width: ProfileImageSize,
                decoration: BoxDecoration(
                  gradient: musicGradient,
                  borderRadius: BorderRadius.circular(ProfileImageSize / 2),
                ),
                child: Container(
                  height: 45.0,
                  width: 45.0,
                  decoration: BoxDecoration(
                    color: settingRepo.setting.value.textColor30,
                    borderRadius: BorderRadius.circular(50),
                    image: new DecorationImage(
                      image: new CachedNetworkImageProvider(soundImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  static showLoaderSpinner() {
    return Center(
      child: Container(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: new AlwaysStoppedAnimation<Color>(settingRepo.setting.value.textColor!),
        ),
      ),
    );
  }

  LinearGradient get musicGradient => LinearGradient(colors: [Colors.grey[800]!, Colors.grey[900]!, Colors.grey[900]!, Colors.grey[800]!], stops: [0.0, 0.4, 0.6, 1.0], begin: Alignment.bottomLeft, end: Alignment.topRight);
}
