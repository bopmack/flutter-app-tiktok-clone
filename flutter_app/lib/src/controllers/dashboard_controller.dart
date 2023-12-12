import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_swiper_plus/flutter_swiper_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
//import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:video_player/video_player.dart';

import '../models/comment_model.dart';
import '../models/videos_model.dart';
import '../repositories/comment_repository.dart' as commentRepo;
import '../repositories/hash_repository.dart' as hashRepo;
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/user_repository.dart' as userRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../services/CacheManager.dart';

class DashboardController extends ControllerMVC {
  int videoId = 0;
  bool completeLoaded = false;
  String commentValue = '';
  bool textFieldMoveToUp = false;
  DateTime currentBackPressTime = DateTime.now();
  GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  PanelController pc = new PanelController();
  PanelController pc2 = new PanelController();
  PanelController pc3 = new PanelController();
  ValueNotifier<bool> hideBottomBar = new ValueNotifier(false);
  ValueNotifier<bool> isVideoInitialized = new ValueNotifier(false);
  ValueNotifier<bool> dataLoaded = new ValueNotifier(false);
  ValueNotifier<bool> likeShowLoader = new ValueNotifier(false);
  ValueNotifier<bool> shareShowLoader = new ValueNotifier(false);
  ValueNotifier<bool> showReportLoader = new ValueNotifier(false);
  ValueNotifier<bool> showReportMsg = new ValueNotifier(false);
  ValueNotifier<bool> loadMoreUpdateView = new ValueNotifier(false);
  ValueNotifier<bool> commentsLoader = new ValueNotifier(false);
  ValueNotifier<bool> soundShowLoader = new ValueNotifier(false);
  ValueNotifier<bool> isFollowedAnyPerson = new ValueNotifier(false);
  ValueNotifier<bool> showFollowingPage = new ValueNotifier(false);
  ValueNotifier<bool> showBannerAd = new ValueNotifier(false);
  ValueNotifier<bool> showHomeLoader = new ValueNotifier(false);
  ValueNotifier<bool> showLikedAnimation = new ValueNotifier(false);
  ValueNotifier<double> descriptionHeight = new ValueNotifier(18.0);
  ScrollController scrollController = new ScrollController();
  ScrollController scrollController1 = new ScrollController();
  List<CommentData> comments = <CommentData>[];
  CommentData commentObj = new CommentData();

  int commentsPaging = 1;
  bool showLoadMoreComments = true;
  int active = 2;
  Map<dynamic, dynamic> map = {};
  bool showLoader = true;
  bool chkVideos = true;
  bool moreVideos = true;
  bool iFollowedAnyUser = false;
  int page = 1;
  int loginUserId = 0;
  String appToken = '';
  List videoList = [];
  // var response;
  int following = 0;
  int isFollowingVideos = 0;
  bool userFollowSuggestion = false;
  bool isLoggedIn = false;
  bool isLiked = false;
  bool videoInitialized = false;
  Map<String, VideoPlayerController?> videoControllers = {};
  Map<String, Future<void>> initializeVideoPlayerFutures = {};
  Map<String, VideoPlayerController?> videoControllers2 = {};
  Map<String, Future<void>> initializeVideoPlayerFutures2 = {};
  Map<int, VoidCallback> listeners = {};
  int index = 0;
  int videoIndex = 0;
  bool lock = true;
  static const double ActionWidgetSize = 60.0;
  static const double ProfileImageSize = 50.0;
  int soundId = 0;
  int userId = 0;
  String totalComments = '0';
  String userDP = '';
  String soundImageUrl = '';
  int isFollowing = 0;
  double paddingBottom = 0;
  ValueNotifier<bool> showFollowLoader = new ValueNotifier(false);
  String encodedVideoId = '';
  String selectedType = "It's spam";
  String encKey = 'yfmtythd84n4h';
  String videoReportDescription = "";
  int chkVideo = 0;
  List<String> reportType = ["It's spam", "It's inappropriate", "I don't like it"];
  bool videoStarted = true;
  int swiperIndex = 0;
  int swiperIndex2 = 0;
  bool initializePage = true;
  SwiperController swipeController = new SwiperController();
  SwiperController swipeController2 = new SwiperController();
  bool showNavigateLoader = false;
  FocusNode inputNode = FocusNode();
  ValueNotifier<int> editedComment = ValueNotifier(0);
  late BannerAd myBanner;
  DashboardController() {
    // videoRepo.userVideoObj.value = {"userId": 0, "videoId": 0, "user": ""};
  }
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  RewardedAd? myRewarded;
  int _numRewardedLoadAttempts = 0;
  int maxFailedLoadAttempts = 3;
  static final AdRequest request = AdRequest(
    keywords: <String>['foo', 'bar'],
    contentUrl: 'http://foo.com/bar.html',
    nonPersonalizedAds: true,
  );
  String appId = '';
  String bannerUnitId = '';
  String screenUnitId = '';
  String videoUnitId = '';
  String bannerShowOn = '';
  String interstitialShowOn = '';
  String videoShowOn = '';
  GlobalKey<FormState> formKey = new GlobalKey<FormState>();
  late VideoPlayerController controller;
  bool lights = false;
  late Duration duration;
  late Duration position;
  bool isEnd = false;
  bool onTap = false;
  late Future<void> initializeVideoPlayerFuture;
  TextEditingController commentController = TextEditingController();
  ValueNotifier<bool> videoReportBlocked = ValueNotifier(false);

  @override
  initState() {
    swiperIndex = 0;
    swiperIndex2 = 0;
    super.initState();
  }

  @override
  dispose() {
    try {
      videoControllers.forEach((key, value) async {
        if (value!.value.isInitialized) {
          await value.dispose();
        }
      });
      videoControllers2.forEach((key, value) async {
        if (value!.value.isInitialized) {
          await value.dispose();
        }
      });
    } catch (e) {
      print("Error Disposing Videos in Dispose function");
    }

    super.dispose();
  }

  updateSwiperIndex(int index) {
    swiperIndex = index;
  }

  updateSwiperIndex2(int index) {
    swiperIndex2 = index;
  }

  onVideoChange(String videoId) {
    videoId = videoId;
  }

  getAds() async {
    var value = await hashRepo.getAds();
    if (value != null) {
      var response = json.decode(value);
      hashRepo.adsData.value = new Map<String, dynamic>.from(json.decode(value));
      hashRepo.adsData.notifyListeners();
      print("getAdsresponse $response");
      appId = Platform.isAndroid ? response['android_app_id'] : response['ios_app_id'];
      bannerUnitId = Platform.isAndroid ? response['android_banner_app_id'] : response['ios_banner_app_id'];
      screenUnitId = Platform.isAndroid ? response['android_interstitial_app_id'] : response['ios_interstitial_app_id'];
      videoUnitId = Platform.isAndroid ? response['android_video_app_id'] : response['ios_video_app_id'];
      bannerShowOn = response['banner_show_on'];
      interstitialShowOn = response['interstitial_show_on'];
      videoShowOn = response['video_show_on'];

      if (appId != "") {
        MobileAds.instance.initialize().then((value) async {
          if (bannerShowOn.indexOf("1") > -1) {
            print("asdzxcqwe");
            showBannerAd.value = true;
            showBannerAd.notifyListeners();
            paddingBottom = Platform.isAndroid ? 50.0 : 80.0;
          }

          if (interstitialShowOn.indexOf("1") > -1) {
            createInterstitialAd(screenUnitId);
          }

          if (videoShowOn.indexOf("1") > -1) {
            await createRewardedAd(videoUnitId);
          }
        });
      }
    }
  }

  createInterstitialAd(adUnitId) {
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Ad loaded.');
          print('$ad loaded');

          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Ad failed to load: $error');
          print('InterstitialAd failed to load: $error.');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            createInterstitialAd(adUnitId);
          }
        },
      ),
    );
    Future<void>.delayed(Duration(seconds: 3), () => _showInterstitialAd(adUnitId));
  }

  void _showInterstitialAd(adUnitId) {
    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) => print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        // createInterstitialAd(adUnitId);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createInterstitialAd(adUnitId);
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  createRewardedAd(adUnitId) {
    RewardedAd.load(
        adUnitId: adUnitId,
        request: request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('$ad loaded.');
            myRewarded = ad;
            _numRewardedLoadAttempts = 0;
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('RewardedAd failed to load: $error');
            myRewarded = null;
            _numRewardedLoadAttempts += 1;
            if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
              createRewardedAd(adUnitId);
            }
          },
        ));

    Future<void>.delayed(Duration(seconds: 10), () => _showRewardedAd(adUnitId));
  }

  void _showRewardedAd(adUnitId) {
    if (myRewarded == null) {
      print('Warning: attempt to show rewarded before loaded.');
      return;
    }
    myRewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) => print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        // createRewardedAd(adUnitId);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createRewardedAd(adUnitId);
      },
    );

    myRewarded!.setImmersiveMode(true);
    myRewarded!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      print('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
    });
    myRewarded = null;
  }

  disposeControls(controls) {
    controls.forEach((key, value2) async {
      await value2.dispose();
    });
  }

  showDeleteAlert(parentContext, errorTitle, errorString, commentId, videoId) {
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return Container(
          color: Colors.transparent,
          height: 200,
          padding: const EdgeInsets.only(
            left: 10,
            right: 10,
          ),
          child: AlertDialog(
            title: Center(
              child: Text(
                errorTitle,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontFamily: 'RockWellStd',
                ),
              ),
            ),
            insetPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/icons/warning.jpg",
                  width: 150,
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                  ),
                  child: Text(
                    errorString,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                      decoration: BoxDecoration(
                        //color: Color(0xff2e2f34),
                        borderRadius: BorderRadius.all(new Radius.circular(32.0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          GestureDetector(
                              onTap: () async {
                                deleteComment(commentId, videoId);
                                Navigator.of(context, rootNavigator: true).pop("Discard");
                              },
                              child: Container(
                                width: 100,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: settingRepo.setting.value.accentColor,
                                  borderRadius: BorderRadius.all(new Radius.circular(5.0)),
                                ),
                                child: Center(
                                  child: Text(
                                    "Yes",
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'RockWellStd'),
                                  ),
                                ),
                              )),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context, rootNavigator: true).pop("Discard");
                            },
                            child: Container(
                              width: 100,
                              height: 35,
                              decoration: BoxDecoration(
                                color: settingRepo.setting.value.accentColor,
                                borderRadius: BorderRadius.all(new Radius.circular(5.0)),
                              ),
                              child: Center(
                                child: Text(
                                  "No",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'RockWellStd',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  deleteComment(commentId, videoId) async {
    videoRepo.deleteComment(commentId, videoId).then((value) async {
      if (value != null) {
        setState(() {
          showLoader = false;
        });
        showLoader = false;
        var response = json.decode(value);
        if (response['status'] != 'success') {
          String msg = response['msg'];
          Fluttertoast.showToast(msg: "Comment deleted Successfully");
        } else {
          Fluttertoast.showToast(msg: "There's some error deleting video");
        }
      }
    });
  }

  checkEulaAgreement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? check = prefs.getBool('EULA_agree');
    if (check != null) {
      if (!check) {
        try {
          userRepo.checkEulaAgreement().then((agree) {
            if (agree) {
              prefs.setBool('EULA_agree', agree);
            } else {
              getEulaAgreement();
            }
          });
        } catch (e) {
          print(e.toString() + "Cache Errors");
        }
      } else {
        return true;
      }
    } else {
      try {
        userRepo.checkEulaAgreement().then((agree) {
          if (agree) {
            prefs.setBool('EULA_agree', agree);
          } else {
            getEulaAgreement();
          }
        });
      } catch (e) {
        print(e.toString() + "Cache Errors");
      }
    }
  }

  Future getEulaAgreement() async {
    try {
      var value = await userRepo.getEulaAgreement();
      print("getEulaAgreement : $value");
      var data = json.decode(value);
      if (isVideoInitialized.value) {
        videoRepo.isOnHomePage.value = false;
        videoRepo.isOnHomePage.notifyListeners();
        if (videoRepo.homeCon.value.showFollowingPage.value) {
          videoRepo.homeCon.value.stopController(videoRepo.homeCon.value.swiperIndex);
        } else {
          print("videoRepo.homeCon.value.swiperIndex2 ${videoRepo.homeCon.value.swiperIndex2}");
          videoRepo.homeCon.value.stopController2(videoRepo.homeCon.value.swiperIndex2);
        }
        Navigator.of(scaffoldKey.currentContext!).pushReplacement(
          MaterialPageRoute(builder: (context) {
            return WillPopScope(
              onWillPop: () {
                DateTime now = DateTime.now();
                if (videoRepo.homeCon.value.pc.isPanelOpen) {
                  videoRepo.homeCon.value.pc.close();
                  return Future.value(false);
                }

                if (now.difference(currentBackPressTime) > Duration(seconds: 2)) {
                  currentBackPressTime = now;
                  Fluttertoast.showToast(msg: "Tap again to exit an app.");
                  return Future.value(false);
                }
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                return Future.value(true);
              },
              child: Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.blueAccent,
                  automaticallyImplyLeading: false,
                  title: Center(
                    child: Text(
                      data['title'],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                body: SingleChildScrollView(
                  child: Html(
                    shrinkWrap: true,
                    data: data['content'],
                  ),
                ),
                floatingActionButton: FloatingActionButton.extended(
                  backgroundColor: Colors.blueAccent,
                  onPressed: () async {
                    var value = await userRepo.agreeEula();
                    print("userRepo.agreeEula() value $value");
                    if (value) {
                      videoRepo.homeCon.value.showFollowingPage.value = false;
                      videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                      videoRepo.homeCon.value.getVideos();
                      Navigator.of(context).pushReplacementNamed('/home');
                    }
                  },
                  icon: Icon(Icons.check),
                  label: Text("Agree"),
                ),
              ),
            );
          }),
        );
      }
      // });

    } catch (e) {
      print(e.toString() + "Cache Errors");
    }
    return true;
  }

  initVideos(length) {
    for (int i = 0; i < length; i++) {
      initController(i).whenComplete(() {
        if (i == 0) {
          videoRepo.dataLoaded.value = true;
          videoRepo.homeCon.value.showHomeLoader.value = false;
          videoRepo.homeCon.value.showHomeLoader.notifyListeners();
          videoRepo.dataLoaded.notifyListeners();
          playController(i);
          isVideoInitialized.value = true;
          isVideoInitialized.notifyListeners();
        } else {
          completeLoaded = true;
        }
      });
    }
  }

  Future<void> getVideos() async {
    isVideoInitialized.value = false;
    isVideoInitialized.notifyListeners();
    swiperIndex = 0;
    swiperIndex2 = 0;
    videoRepo.videosData.value.videos = [];
    videoRepo.videosData.notifyListeners();
    initializeVideoPlayerFutures = {};
    initializeVideoPlayerFutures2 = {};
    page = 1;
    formKey = GlobalKey();
    getAds();
    Map obj = {'userId': 0, 'videoId': 0};

    if (videoRepo.userVideoObj.value.userId > 0) {
      obj['userId'] = videoRepo.userVideoObj.value.userId;
      obj['videoId'] = videoRepo.userVideoObj.value.videoId;
    } else if (videoRepo.userVideoObj.value.videoId > 0) {
      obj['videoId'] = videoRepo.userVideoObj.value.videoId;
    }
    if (videoRepo.userVideoObj.value.hashTag != "") {
      obj['hashtag'] = videoRepo.userVideoObj.value.hashTag;
    }

    videoRepo.getVideos(page, obj).then((data1) async {
      if (data1 != VideoModel()) {
        if (data1.videos.isNotEmpty) {
          if (data1.videos.length > 0 && data1.videos.length >= 1) {
            await initVideos(2);
          } else {
            initializeVideoPlayerFutures = {};
            initializeVideoPlayerFutures2 = {};
          }
        } else {
          initializeVideoPlayerFutures = {};
          initializeVideoPlayerFutures2 = {};
        }
      }
    });
  }

  Future<void> getFollowingUserVideos() async {
    isVideoInitialized.value = false;
    isVideoInitialized.notifyListeners();
    initializeVideoPlayerFutures = {};
    initializeVideoPlayerFutures2 = {};
    page = 1;
    formKey = GlobalKey();
    videoRepo.getFollowingUserVideos(page).then((data2) async {
      if (data2 != VideoModel()) {
        if (data2.videos.length > 0) {
          initController2(0).whenComplete(() {
            playController2(0);
            videoRepo.dataLoaded.value = true;
            videoRepo.dataLoaded.notifyListeners();
          });
        } else {
          initializeVideoPlayerFutures = {};
          initializeVideoPlayerFutures2 = {};
        }

        if (data2.videos.length > 1) {
          initController2(1).then((value) => completeLoaded = true);
        }
      } else {
        initializeVideoPlayerFutures = {};
        initializeVideoPlayerFutures2 = {};
      }
    });
  }

  Future<void> listenForMoreVideos() async {
    Map obj = {'userId': 0, 'videoId': 0};
    if (videoRepo.userVideoObj.value.userId > 0) {
      obj['userId'] = videoRepo.userVideoObj.value.userId;
      obj['videoId'] = videoRepo.userVideoObj.value.videoId;
    } else if (videoRepo.userVideoObj.value.videoId > 0) {
      obj['videoId'] = videoRepo.userVideoObj.value.videoId;
    } else if (videoRepo.userVideoObj.value.hashTag != "") {
      obj['hashtag'] = videoRepo.userVideoObj.value.hashTag;
    }
    page = page + 1;
    videoRepo.getVideos(page, obj).whenComplete(() {
      // loadMoreUpdateView.value = true;
      // loadMoreUpdateView.notifyListeners();
    });
  }

  Future<void> listenForMoreUserFollowingVideos() async {
    page = page + 1;
    videoRepo.getFollowingUserVideos(page).whenComplete(() {
      loadMoreUpdateView.value = true;
      loadMoreUpdateView.notifyListeners();
    });
  }

  Future<void> likeVideo(int index) async {
    likeShowLoader.value = true;
    likeShowLoader.notifyListeners();
    videoRepo.videosData.value.videos.elementAt(index).totalLikes = (!videoRepo.videosData.value.videos.elementAt(index).isLike)
        ? videoRepo.videosData.value.videos.elementAt(index).totalLikes + 1
        : videoRepo.videosData.value.videos.elementAt(index).totalLikes - 1;
    videoRepo.videosData.value.videos.elementAt(index).isLike = (videoRepo.videosData.value.videos.elementAt(index).isLike) ? false : true;
    print("videoRepo.videosData.value.videos.elementAt(index).videoId ${videoRepo.videosData.value.videos.elementAt(index).videoId}");
    videoRepo.updateLike(videoRepo.videosData.value.videos.elementAt(index).videoId).whenComplete(() {
      likeShowLoader.value = false;
      likeShowLoader.notifyListeners();
    }).catchError((e) {
      likeShowLoader.value = false;
      likeShowLoader.notifyListeners();
    });
  }

  Future<void> likeFollowingVideo(int index) async {
    likeShowLoader.value = true;
    likeShowLoader.notifyListeners();
    videoRepo.followingUsersVideoData.value.videos.elementAt(index).totalLikes = (!videoRepo.videosData.value.videos.elementAt(index).isLike)
        ? videoRepo.followingUsersVideoData.value.videos.elementAt(index).totalLikes + 1
        : videoRepo.followingUsersVideoData.value.videos.elementAt(index).totalLikes - 1;
    videoRepo.followingUsersVideoData.value.videos.elementAt(index).isLike = (videoRepo.videosData.value.videos.elementAt(index).isLike) ? false : true;
    print("videoRepo.followingUsersVideoData.value.videos.elementAt(index).videoId ${videoRepo.followingUsersVideoData.value.videos.elementAt(index).videoId}");
    videoRepo.updateLike(videoRepo.followingUsersVideoData.value.videos.elementAt(index).videoId).whenComplete(() {
      likeShowLoader.value = false;
      likeShowLoader.notifyListeners();
    }).catchError((e) {
      likeShowLoader.value = false;
      likeShowLoader.notifyListeners();
    });
  }

  /*Future<void> submitReport(Video videoObj, context) async {
    showReportLoader.value = true;
    showReportLoader.notifyListeners();
    videoRepo.submitReport(videoObj, selectedType, description).whenComplete(() {
      showReportLoader.value = false;
      showReportLoader.notifyListeners();
      selectedType = "";
      description = '';
      showReportMsg.value = true;
      showReportMsg.notifyListeners();
      Timer(Duration(seconds: 5), () {
        if (!showFollowingPage.value) {
          videoRepo.videosData.value.videos.removeWhere((element) => element.videoId == videoObj.videoId);
          videoRepo.videosData.notifyListeners();
        } else {
          videoRepo.followingUsersVideoData.value.videos.removeWhere((element) => element.videoId == videoObj.videoId);
          videoRepo.followingUsersVideoData.notifyListeners();
        }
        Navigator.of(context).pop();
      });
    }).catchError((e) {});
  }*/
  Future<void> submitReport(Video videoObj, context) async {
    showReportLoader.value = true;
    showReportLoader.notifyListeners();
    videoRepo.submitReport(videoObj, selectedType, videoReportDescription, videoReportBlocked.value).whenComplete(() {
      showReportLoader.value = false;
      showReportLoader.notifyListeners();
      selectedType = "It's spam";
      videoReportDescription = '';
      showReportMsg.value = true;
      showReportMsg.notifyListeners();
      Timer(Duration(seconds: 5), () {
        if (!showFollowingPage.value) {
          removeController(videoRepo.homeCon.value.swiperIndex);
          videoRepo.videosData.value.videos.removeWhere((element) => element.videoId == videoObj.videoId);
          videoRepo.videosData.notifyListeners();
          if (videoRepo.videosData.value.videos.length - 1 > videoRepo.homeCon.value.swiperIndex) {
            nextVideo(videoRepo.homeCon.value.swiperIndex);
          } else {
            previousVideo(videoRepo.homeCon.value.swiperIndex);
          }
        } else {
          removeController2(videoRepo.homeCon.value.swiperIndex2);
          videoRepo.followingUsersVideoData.value.videos.removeWhere((element) => element.videoId == videoObj.videoId);
          videoRepo.followingUsersVideoData.notifyListeners();
          if (videoRepo.videosData.value.videos.length - 1 > videoRepo.homeCon.value.swiperIndex) {
            nextVideo2(videoRepo.homeCon.value.swiperIndex2);
          } else {
            previousVideo2(videoRepo.homeCon.value.swiperIndex2);
          }
        }
        Navigator.of(context).pop();
      });
    }).catchError((e) {});
  }

  Future<void> getComments(Video videoObj) async {
    comments = [];
    showLoadMoreComments = true;
    page = 1;
    scrollController = new ScrollController();
    scrollController1 = new ScrollController();
    final List<CommentData> newComments = await commentRepo.getComments(videoObj.videoId, page);
    comments.addAll(newComments);
    if (comments.length == videoObj.totalComments) {
      showLoadMoreComments = false;
    }
    scrollController.addListener(() {
      if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
        if (comments.length != videoObj.totalComments && showLoadMoreComments) {
          loadMore(videoObj);
        }
      }
    });
  }

  Future<void> loadMore(Video videoObj) async {
    commentsLoader.value = true;
    commentsLoader.notifyListeners();
    page = page + 1;
    final List<CommentData> newComments = await commentRepo.getComments(videoObj.videoId, page);
    comments.addAll(newComments);
    commentsLoader.value = false;
    commentsLoader.notifyListeners();
    if (comments.length == videoObj.totalComments) {
      showLoadMoreComments = false;
    }
    loadMoreUpdateView.value = true;
    loadMoreUpdateView.notifyListeners();
  }

  Future<void> addComment(int videoId, context) async {
    FocusScope.of(context).unfocus();
    commentController = new TextEditingController(text: "");
    commentObj = new CommentData();
    commentObj.videoId = videoId;
    commentObj.comment = commentValue;
    commentObj.userId = userRepo.currentUser.value.userId;
    commentObj.token = userRepo.currentUser.value.token;
    commentObj.userDp = userRepo.currentUser.value.userDP;
    commentObj.userName = userRepo.currentUser.value.userName;
    commentObj.time = 'now';
    commentValue = '';
    if (!showFollowingPage.value) {
      videoRepo.videosData.value.videos.elementAt(swiperIndex).totalComments = videoRepo.videosData.value.videos.elementAt(swiperIndex).totalComments + 1;
    } else {
      videoRepo.followingUsersVideoData.value.videos.elementAt(swiperIndex2).totalComments = videoRepo.followingUsersVideoData.value.videos.elementAt(swiperIndex2).totalComments + 1;
    }

    await commentRepo.addComment(commentObj).then((commentId) {
      commentObj.commentId = commentId;
      comments.insert(0, commentObj);
      loadMoreUpdateView.value = true;
      loadMoreUpdateView.notifyListeners();
      videoRepo.homeCon.value.scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }).catchError((e) {
      context.showSnackBar(SnackBar(
        content: Text("There's some issue with the server"),
      ));
    });
  }

  Future<void> onEditComment(index, context) async {
    FocusScope.of(context).requestFocus(inputNode);
    editedComment.value = index;
    editedComment.notifyListeners();
    commentController = new TextEditingController(text: videoRepo.homeCon.value.comments[index - 1].comment);
  }

  Future<void> editComment(index, videoId, context) async {
    FocusScope.of(context).unfocus();
    commentController = new TextEditingController(text: "");
    commentObj = new CommentData();
    commentObj.commentId = videoRepo.homeCon.value.comments[index].commentId;
    commentObj.videoId = videoId;
    commentObj.comment = commentValue;
    commentObj.userId = userRepo.currentUser.value.userId;
    commentObj.token = userRepo.currentUser.value.token;
    commentObj.userDp = userRepo.currentUser.value.userDP;
    commentObj.userName = userRepo.currentUser.value.userName;
    commentObj.time = videoRepo.homeCon.value.comments[index].time;
    commentValue = '';
    await commentRepo.editComment(commentObj).then((resposne) {
      if (resposne != null) {
        editedComment.value = 0;
        editedComment.notifyListeners();
        comments[index] = commentObj;
        loadMoreUpdateView.value = true;
        loadMoreUpdateView.notifyListeners();
      }
    }).catchError((e) {
      context.showSnackBar(SnackBar(
        content: Text("There's some issue with the server"),
      ));
    });
  }

  videoController(int index) {
    if (videoRepo.videosData.value.videos.length > 0) {
      return videoControllers[videoRepo.videosData.value.videos.elementAt(index).url];
    }
  }

  videoController2(int index) {
    if (videoRepo.followingUsersVideoData.value.videos.length > 0) {
      return videoControllers2[videoRepo.followingUsersVideoData.value.videos.elementAt(index).url];
    }
  }

  Future<void> initController(int index) async {
    try {
      var controller = await getControllerForVideo(videoRepo.videosData.value.videos.elementAt(index).url);
      videoControllers[videoRepo.videosData.value.videos.elementAt(index).url] = controller;
      // initializeVideoPlayerFutures[videoRepo.videosData.value.videos.elementAt(index).url] = controller.initialize().onError((error, stackTrace) => print("Init Error: $error"));
      initializeVideoPlayerFutures[videoRepo.videosData.value.videos.elementAt(index).url] = controller.initialize();
      controller.setLooping(true);
    } on PlatformException catch (e) {
      print("Init Catch Error: $e");
    }
  }

  Future<VideoPlayerController> getControllerForVideo(String video) async {
    // try {
    // final fileInfo = await CustomCacheManager.instance.getFileFromCache(video);
    VideoPlayerController controller;
    double volume = 1;

    /*if (fileInfo == null || fileInfo.file == null) {
        // unawaited(CustomCacheManager.instance.downloadFile(video).whenComplete(() => print('saved video url $video')));*/
    controller = VideoPlayerController.network(video);
    controller.setVolume(volume);
    return controller;
    /* } else {
        controller = VideoPlayerController.file(fileInfo.file);
        controller.setVolume(volume);
        return controller;
      }*/
    /*} catch (e) {
      return VideoPlayerController.network("");
    }*/
  }

  Future<void> initController2(int index) async {
    try {
      var controller = await getControllerForVideo(videoRepo.followingUsersVideoData.value.videos.elementAt(index).url);
      videoControllers2[videoRepo.followingUsersVideoData.value.videos.elementAt(index).url] = controller;
      initializeVideoPlayerFutures2[videoRepo.followingUsersVideoData.value.videos.elementAt(index).url] = controller.initialize().onError((error, stackTrace) => print("OnErrorException: $error"));
      controller.setLooping(true);
    } catch (e) {
      print("Init Catch Error: $e");
    }
  }

  void removeController(int count) async {
    try {
      // videoController(count).value.dispose();
      await videoController(count)?.dispose();
      videoControllers.remove(videoRepo.videosData.value.videos.elementAt(count).url);
      initializeVideoPlayerFutures.remove(videoRepo.videosData.value.videos.elementAt(count).url);
    } catch (e) {
      print("Catch: $e");
    }
  }

  void removeController2(int count) async {
    try {
      await videoController2(count).dispose();
      videoControllers2.remove(videoRepo.followingUsersVideoData.value.videos.elementAt(count).url);
      initializeVideoPlayerFutures2.remove(videoRepo.followingUsersVideoData.value.videos.elementAt(count).url);
    } catch (e) {
      print("Catch: $e");
    }
  }

  void stopController(int index) {
    try {
      print("stopController isInitialized $index");
      print(videoController(index).value!.isInitialized);
      if (videoController(index) != null || videoController(index).value.isInitialized) videoController(index).pause();
      print("paused $index");
    } catch (e) {
      print("Error pausing stopController $index $e");
    }
  }

  void playController(int index) async {
    if (videoRepo.isOnHomePage.value) {
      print(index);
      try {
        print("playController isInitialized $index");
        print(videoController(index).value.isInitialized);
        if (videoController(index) != null) videoController(index).play();
      } catch (e) {
        print("Error playing playController $index $e");
      }
    }
  }

  void stopController2(int index) {
    try {
      print("stopController2 isInitialized $index");

      if (videoController2(index) != null && videoController2(index).value.isInitialized) videoController2(index).pause();
    } catch (e) {
      print("Error pausing stopController2 $index $e");
    }
  }

  void playController2(int index) async {
    if (videoRepo.isOnHomePage.value) {
      try {
        print("playController2 isInitialized $index");
        if (videoController2(index) != null) videoController2(index).play();
      } catch (e) {
        print("Error playing playController2 $index $e");
      }
    }
  }

  //Swipe Prev Video
  void previousVideo(ind) async {
    if (ind < 0) {
      return;
    }
    lock = true;
    stopController(ind + 1);

    if (ind + 2 < videoRepo.videosData.value.videos.length) {
      removeController(ind + 2);
    }
    playController(ind);
    if (ind == 0) {
      lock = false;
    } else {
      initController(ind - 1).whenComplete(() => lock = false);
    }
  }

  void previousVideo2(ind) async {
    if (ind < 0) {
      return;
    }
    lock = true;
    stopController2(ind + 1);

    if (ind + 2 < videoRepo.followingUsersVideoData.value.videos.length) {
      removeController2(ind + 2);
    }

    playController2(ind);

    if (ind == 0) {
      lock = false;
    } else {
      initController2(ind - 1).whenComplete(() => lock = false);
    }
  }

  //Swipe Next Video
  void nextVideo(ind) async {
    if (ind > videoRepo.videosData.value.videos.length - 1) {
      return;
    }
    lock = true;
    stopController(ind - 1);
    if (ind - 2 >= 0) {
      removeController(ind - 2);
    }
    playController(ind);
    if (ind == videoRepo.videosData.value.videos.length - 1) {
      lock = false;
    } else {
      initController(ind + 1).whenComplete(() => lock = false);
    }
  }

  void nextVideo2(ind) async {
    if (ind > videoRepo.followingUsersVideoData.value.videos.length - 1) {
      return;
    }
    lock = true;
    stopController2(ind - 1);
    if (ind - 2 >= 0) {
      removeController2(ind - 2);
    }
    playController2(ind);
    if (ind != videoRepo.followingUsersVideoData.value.videos.length - 1) {
      initController2(ind + 1);
    }
  }

  Future<void> preCacheVideos() {
    /*for (final e in videoRepo.videosData.value.videos) {
      Video video = e;
      try {
        CustomCacheManager.instance.downloadFile(video.url);
      } on HttpException catch (e) {
        print("Cache preCacheVideos Errors $e");
      }
    }*/
    return Future.value();
  }

  Future<void> preCacheVideoThumbs() {
    for (final e in videoRepo.videosData.value.videos) {
      Video video = e;
      try {
        CustomCacheManager.instance.downloadFile(video.videoThumbnail);
      } on HttpException catch (e) {
        print("Cache preCacheVideos Errors $e");
      }
    }
    return Future.value();
  }

  Future<void> followUnfollowUser(Video videoObj) async {
    showFollowLoader.value = true;
    showFollowLoader.notifyListeners();
    if (videoRepo.homeCon.value.showFollowingPage.value) {
      if (videoRepo.followingUsersVideoData.value.videos.length == 1 && videoRepo.followingUsersVideoData.value.videos.elementAt(videoRepo.homeCon.value.swiperIndex2).followText == "Unfollow") {
        videoRepo.homeCon.value.videoController2(videoRepo.homeCon.value.swiperIndex2).pause();
      }
    }

    videoRepo.followUnfollowUser(videoObj).then((value) {
      showFollowLoader.value = false;
      showFollowLoader.notifyListeners();
      var response = json.decode(value);
      if (response['status'] == 'success') {
        videoObj.isFollowing = response['followText'] == 'Follow' ? 0 : 1;
        loadMoreUpdateView.value = true;
        loadMoreUpdateView.notifyListeners();
        for (var item in videoRepo.videosData.value.videos) {
          if (videoObj.userId == item.userId) {
            item.isFollowing = response['followText'] == 'Follow' ? 0 : 1;
          }
        }
      }
    }).catchError((e) {
      showFollowLoader.value = false;
      showFollowLoader.notifyListeners();
    });
  }
}
