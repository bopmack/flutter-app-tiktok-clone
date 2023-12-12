import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:pedantic/pedantic.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

import '../controllers/dashboard_controller.dart';
import '../helpers/app_config.dart' as config;
import '../helpers/global_keys.dart';
import '../models/login_model.dart';
import '../models/users_model.dart';
import '../models/videos_model.dart';
import '../repositories/chat_repository.dart' as chatRepo;
import '../repositories/notification_repository.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/user_repository.dart' as userRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../views/chat_view.dart';
import '../views/internet_view.dart';
import '../views/user_profile_view.dart';

class SplashScreenController extends ControllerMVC {
  ValueNotifier<bool> processing = new ValueNotifier(true);
  DashboardController homeCon = DashboardController();
  String uniqueId = "";
  GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  late StreamSubscription _sub;
  // double percent = 0.0;
  late Timer timer;
  ValueNotifier<bool> redirection = new ValueNotifier(true);
  bool isInternetOn = true;
  // bool firstTimeLoad = false;
  final Connectivity _connectivity = Connectivity();
  static const platform = const MethodChannel('com.flutter.epic/epic');

  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  ValueNotifier<double> loadingPercent = new ValueNotifier(0.0);

  Future<void> initializeVideos() async {
    this.scaffoldKey = new GlobalKey<ScaffoldState>();
  }

  pushNotifications() {
    print("pushNotifications");
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      print("pushNotifications3333 $message");
      if (message != null) {
        notificationAction(message.data);
        setState(() {
          redirection.value = false;
          redirection.notifyListeners();
        });
      }
    });
    print("pushNotifications2");
    FirebaseMessaging.onMessage.listen((RemoteMessage? message) {
      print("pushNotifications3");
      RemoteNotification notification = message!.notification!;
      print("djsadagdgsdgd ${message.data}");
      //AndroidNotification android = message.notification?.android;
      if (notification != null) {
        String type = message.data['type'];
        int id = int.parse(message.data['id']);
        if (type == "chat") {
          videoRepo.unreadMessageCount.value++;
          videoRepo.unreadMessageCount.notifyListeners();
          if (id != chatRepo.convId) {
            chatRepo.myConversations(1, '');
            ScaffoldMessenger.of(GlobalVariable.navState.currentContext!).showSnackBar(
              SnackBar(
                backgroundColor: settingRepo.setting.value.buttonColor,
                action: SnackBarAction(
                  label: 'Open',
                  textColor: settingRepo.setting.value.textColor,
                  onPressed: () {
                    notificationAction(message.data);
                  },
                ),
                content: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    notification.title! + " " + notification.body!,
                    style: TextStyle(color: settingRepo.setting.value.textColor, fontSize: 16),
                  ),
                ),
                duration: Duration(seconds: 5),
                width: config.App(GlobalVariable.navState.currentContext).appWidth(90), // Width of the SnackBar.
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0, // Inner padding for SnackBar content.
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(GlobalVariable.navState.currentContext!).showSnackBar(
            SnackBar(
              backgroundColor: settingRepo.setting.value.buttonColor,
              action: SnackBarAction(
                label: 'Open',
                textColor: settingRepo.setting.value.textColor,
                onPressed: () {
                  notificationAction(message.data);
                },
              ),
              content: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  notification.title! + " " + notification.body!,
                  style: TextStyle(color: settingRepo.setting.value.textColor, fontSize: 16),
                ),
              ),
              duration: Duration(seconds: 5),
              width: config.App(GlobalVariable.navState.currentContext).appWidth(90), // Width of the SnackBar.
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0, // Inner padding for SnackBar content.
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      String type = message.data['type'];
      int id = int.parse(message.data['id']);
      if (type == "chat") {
        if (id != chatRepo.convId) {
          chatRepo.myConversations(1, '');
          notificationAction(message.data);
        }
      } else {
        notificationAction(message.data);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('B new onMessageOpenedApp event was published!');
      String type = message.data['type'];
      int id = int.parse(message.data['id']);
      print("ConvIDS ${chatRepo.convId}  ------ ${message.data}");
      if (type == "chat") {
        if (id != chatRepo.convId) {
          print("iFFF");
          chatRepo.myConversations(1, '');
          // notificationAction(message.data);
        }
      } else {
        print("ELSEEEE");
        // notificationAction(message.data);
      }
    });

    FirebaseMessaging.onBackgroundMessage((message) {
      print('C new onMessageOpenedApp event was published!');
      String type = message.data['type'];
      int id = int.parse(message.data['id']);
      if (type == "chat") {
        if (id != chatRepo.convId) {
          chatRepo.myConversations(1, '');
          return notificationAction(message.data);
        } else {
          return notificationsList(1);
        }
      } else {
        return notificationAction(message.data);
      }
    });
  }

  notificationAction(message) {
    String type = message['type'];
    int id = int.parse(message['id']);
    if (type == "like" || type == "comment" || type == "video") {
      videoRepo.userVideoObj.value.videoId = id;
      videoRepo.userVideoObj.notifyListeners();
      videoRepo.homeCon.value.getVideos();
      Navigator.of(GlobalVariable.navState.currentContext!).pushReplacementNamed('/home');
      if (type == "comment") {
        Timer(Duration(seconds: 2), () {
          videoRepo.homeCon.value.hideBottomBar.value = true;
          videoRepo.homeCon.value.hideBottomBar.notifyListeners();
          videoRepo.homeCon.value.videoIndex = 0;
          videoRepo.homeCon.value.showBannerAd.value = false;
          videoRepo.homeCon.value.showBannerAd.notifyListeners();
          videoRepo.homeCon.value.pc.open();
          Video videoObj = new Video();
          videoObj.videoId = id;
          videoRepo.homeCon.value.getComments(videoObj).whenComplete(() {
            videoRepo.commentsLoaded.value = true;
            videoRepo.commentsLoaded.notifyListeners();
          });
        });
      }
    } else if (type == "follow") {
      Navigator.pushReplacement(
        GlobalVariable.navState.currentContext!,
        MaterialPageRoute(
          builder: (context) => UsersProfileView(
            userId: id,
          ),
        ),
      );
    } else if (type == "chat") {
      int userId = int.parse(message['user_id']);
      String personName = message['person_name'];
      String userDp = message['user_dp'];
      OnlineUsersModel _onlineUsersModel = new OnlineUsersModel();
      _onlineUsersModel.convId = id;
      _onlineUsersModel.id = userId;
      _onlineUsersModel.name = personName;
      _onlineUsersModel.userDp = userDp;

      Navigator.pushReplacement(
        GlobalVariable.navState.currentContext!,
        MaterialPageRoute(
          builder: (context) => ChatView(userObj: _onlineUsersModel),
        ),
      );
    }
  }

  initializing() async {
    // await initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    // if (isInternetOn) {
    //   loadData();
    timer = Timer.periodic(Duration(milliseconds: 200), (_) {
      print('Percent Update');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        loadingPercent.value += 1;
        if (loadingPercent.value >= 100) {
          timer.cancel();
          // percent=0;
        }
        loadingPercent.notifyListeners();
      });
    });
    // }
  }

  /*Future<void> initConnectivity() async {
    ConnectivityResult result = ConnectivityResult.none;
    try {
      result = await _connectivity.checkConnectivity();
      if (result != ConnectivityResult.wifi && result != ConnectivityResult.mobile) {
        _updateConnectionStatus(result);
        isInternetOn = false;
      }
    } on PlatformException catch (e) {
      print(e.toString());
    }
  }*/

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    print("_updateConnectionStatus ");
    switch (result) {
      case ConnectivityResult.wifi:
        print("Internet (wifi)");
        isInternetOn = true;
        if (!settingRepo.firstTimeLoad) {
          if (videoRepo.isOnNoInternetPage.value) {
            Navigator.maybePop(GlobalVariable.navState.currentContext!);
          }
        } else {
          print("Internet (wifi) but first load");
          await loadData();
        }
        break;
      case ConnectivityResult.mobile:
        print("Internet (mobile)");
        isInternetOn = true;
        if (!settingRepo.firstTimeLoad) {
          if (videoRepo.isOnNoInternetPage.value) {
            Navigator.maybePop(GlobalVariable.navState.currentContext!);
          }
        } else {
          print("Internet (mobile) but first load");
          await loadData();
        }
        break;
      case ConnectivityResult.none:
        videoRepo.isOnNoInternetPage.value = true;
        videoRepo.isOnNoInternetPage.notifyListeners();
        Navigator.push(
          GlobalVariable.navState.currentContext!,
          MaterialPageRoute(
            builder: (context) => InternetPage(),
          ),
        );
        isInternetOn = false;
        print("Internet (closed)");
        break;
      default:
        videoRepo.isOnNoInternetPage.value = true;
        videoRepo.isOnNoInternetPage.notifyListeners();
        Navigator.push(
          GlobalVariable.navState.currentContext!,
          MaterialPageRoute(
            builder: (context) => InternetPage(),
          ),
        );
        isInternetOn = false;
        print("Internet (def)");
        break;
    }
  }

  printHashKeyOnConsoleLog() async {
    try {
      await platform.invokeMethod("printHashKeyOnConsoleLog");
    } catch (e) {
      print(e);
    }
  }

  Future<void> initUniLinks() async {
    _sub = uriLinkStream.listen((Uri? uri) {
      var id;
      if (Platform.isIOS) {
        var urlList = uri.toString().split("/");
        String encodedId = urlList.last;
        Codec<String, String> stringToBase64 = utf8.fuse(base64);
        id = stringToBase64.decode(encodedId);
      } else {
        id = uri!.queryParameters['id'];
      }
      if (id != "" && id != null && redirection.value == true) {
        videoRepo.userVideoObj.value.videoId = int.parse(id);
        videoRepo.userVideoObj.notifyListeners();
        videoRepo.homeCon.value.getVideos();
        Navigator.of(GlobalVariable.navState.currentContext!).pushReplacementNamed('/home', arguments: 0);
      }
    }, onError: (err) {});
    if (!_sub.isPaused && redirection.value == true) {
      try {
        final initialLink = await getInitialLink();
        if (initialLink != null) {
          var id;
          if (Platform.isIOS) {
            var urlList = Uri.parse(initialLink).toString().split("/");
            String encodedId = urlList.last;
            Codec<String, String> stringToBase64 = utf8.fuse(base64);
            id = stringToBase64.decode(encodedId);
          } else {
            id = Uri.parse(initialLink).queryParameters['id'];
          }
          if (id != "" && id != null) {
            videoRepo.userVideoObj.value.videoId = int.parse(id);
            videoRepo.userVideoObj.notifyListeners();
            videoRepo.homeCon.value.getVideos();
            Navigator.of(GlobalVariable.navState.currentContext!).pushReplacementNamed('/home');
          } else {
            videoRepo.homeCon.value.getVideos();
            Navigator.of(GlobalVariable.navState.currentContext!).pushReplacementNamed('/home');
          }
        } else {
          videoRepo.homeCon.value.showFollowingPage.value = false;
          videoRepo.homeCon.value.showFollowingPage.notifyListeners();
          videoRepo.homeCon.value.getVideos();
          Navigator.of(GlobalVariable.navState.currentContext!).pushReplacementNamed('/home');
        }
      } on PlatformException {
        print("Error.....");
      }
    }
  }

  Future<void> addGuestUserForFCMToken() async {
    String? platformId = await PlatformDeviceId.getDeviceId;
    FirebaseMessaging.instance.getToken().then((value) {
      if (value != "" && value != null) {
        videoRepo.addGuestUser(value, platformId);
      }
    });
  }

  Future<void> updateFCMTokenForUser() async {
    FirebaseMessaging.instance.getToken().then((value) {
      if (value != "" && value != null) {
        videoRepo.updateFcmToken(value);
      }
    });
  }

  Future<void> loadData() async {
    print("settingRepo.setting.value.fetched ${settingRepo.setting.value.fetched}");
    if (!settingRepo.setting.value.fetched) {
      settingRepo.setting.value.fetched = true;
      // printHashKeyOnConsoleLog();
      await settingRepo.initSettings();
      await userUniqueId();
      await checkIfAuthenticated();
      if (userRepo.currentUser.value == null || userRepo.currentUser.value.token == '') {
        addGuestUserForFCMToken();
      } else {
        updateFCMTokenForUser();
      }
      // if (mounted) {
      pushNotifications();
      initUniLinks();
      unawaited(videoRepo.homeCon.value.preCacheVideoThumbs());
      loadingPercent.value = 100;
      loadingPercent.notifyListeners();
      timer.cancel();

      // }
    }
  }

  Future<void> userUniqueId() async {
    final SharedPreferences pref = await SharedPreferences.getInstance();
    uniqueId = (pref.getString('unique_id') == null) ? "" : pref.getString('unique_id').toString();
    if (uniqueId == "") {
      userRepo.userUniqueId().then((value) {
        var jsonData = json.decode(value);
        uniqueId = jsonData['unique_token'];
      });
    }
  }

  Future<void> checkIfAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_user')) {
      String cu = prefs.get('current_user').toString();

      userRepo.currentUser.value = LoginData.fromJson(json.decode(cu));
    }
    if (userRepo.currentUser.value.token == '') {
      return;
    }
    var check = await userRepo.checkIfAuthenticated();
    if (check != null) {
      await userRepo.setCurrentUser(check);
    } else {
      userRepo.currentUser.value = new LoginData();

      await prefs.remove('current_user');
    }
  }
}
