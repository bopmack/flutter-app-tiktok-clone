import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../models/search_model.dart';
import '../repositories/hash_repository.dart' as hashRepo;
import '../repositories/video_repository.dart' as videoRepo;
import 'dashboard_controller.dart';

class HashVideosController extends ControllerMVC {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<ScaffoldState> hashScaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<FormState> formKey = new GlobalKey<FormState>();
  PanelController pc = new PanelController();
  ScrollController scrollController = new ScrollController();
  ScrollController hashScrollController = new ScrollController();
  ScrollController videoScrollController = new ScrollController();
  ScrollController userScrollController = new ScrollController();
  ValueNotifier<bool> showLoader = ValueNotifier(false);
  bool showLoadMore = true;
  bool showLoadMoreHashTags = true;
  bool showLoadMoreUsers = true;
  bool showLoadMoreVideos = true;
  String searchKeyword = '';
  DashboardController homeCon = DashboardController();
  var searchController = TextEditingController();

  String appId = '';
  String bannerUnitId = '';
  String screenUnitId = '';
  String videoUnitId = '';
  String bannerShowOn = '';
  String interstitialShowOn = '';
  String videoShowOn = '';
  int hashesPage = 2;
  int videosPage = 2;
  int usersPage = 2;
  ValueNotifier<bool> showBannerAd = new ValueNotifier(false);
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
  HashVideosController() {}

  @override
  void initState() {
    scaffoldKey = new GlobalKey<ScaffoldState>();
    hashScaffoldKey = new GlobalKey<ScaffoldState>();
    formKey = new GlobalKey<FormState>();
    super.initState();
  }

  getAds() {
    appId = Platform.isAndroid ? hashRepo.adsData.value['android_app_id'] : hashRepo.adsData.value['ios_app_id'];
    bannerUnitId = Platform.isAndroid ? hashRepo.adsData.value['android_banner_app_id'] : hashRepo.adsData.value['ios_banner_app_id'];
    screenUnitId = Platform.isAndroid ? hashRepo.adsData.value['android_interstitial_app_id'] : hashRepo.adsData.value['ios_interstitial_app_id'];
    videoUnitId = Platform.isAndroid ? hashRepo.adsData.value['android_video_app_id'] : hashRepo.adsData.value['ios_video_app_id'];
    bannerShowOn = hashRepo.adsData.value['banner_show_on'];
    interstitialShowOn = hashRepo.adsData.value['interstitial_show_on'];
    videoShowOn = hashRepo.adsData.value['video_show_on'];
    if (appId != "") {
      MobileAds.instance.initialize().then((value) async {
        if (bannerShowOn.indexOf("3") > -1) {
          showBannerAd.value = true;
          showBannerAd.notifyListeners();
        }
        if (interstitialShowOn.indexOf("3") > -1) {
          createInterstitialAd(screenUnitId);
        }
        if (videoShowOn.indexOf("3") > -1) {
          await createRewardedAd(videoUnitId);
        }
      });
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
    print("createRewardedAd");
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

  Future getData(page) async {
    videoRepo.userVideoObj.value.userId = 0;
    videoRepo.userVideoObj.value.videoId = 0;
    videoRepo.userVideoObj.notifyListeners();
    // setState(() {
    showLoadMoreHashTags = true;
    showLoadMoreUsers = true;
    showLoadMoreVideos = true;
    hashesPage = 2;
    usersPage = 2;
    videosPage = 2;
    // });
    showLoader.value = true;
    showLoader.notifyListeners();
    scrollController = new ScrollController();
    hashRepo.getData(page, searchKeyword, hashTag: videoRepo.currentHashTag.value.tag).then((value) {
      showLoader.value = false;
      showLoader.notifyListeners();
      if (value.videos.length == value.totalRecords) {
        showLoadMore = false;
      }
      scrollController.addListener(() {
        if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
          if (value.videos.length != value.totalRecords && showLoadMore) {
            page = page + 1;
            getData(page);
          }
        }
      });
    });
  }

  Future getHashData(page, hash) async {
    videoRepo.userVideoObj.value.userId = 0;
    videoRepo.userVideoObj.value.videoId = 0;
    videoRepo.userVideoObj.notifyListeners();
    homeCon.notifyListeners();
    showLoader.value = true;
    showLoader.notifyListeners();
    scrollController = new ScrollController();
    hashRepo.getHashData(page, hash).then((value) {
      if (value != null) {
        showLoader.value = false;
        showLoader.notifyListeners();
        if (value.videos.length == value.totalRecords) {
          showLoadMore = false;
        }
        scrollController.addListener(() {
          if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
            if (value.videos.length != value.totalRecords && showLoadMore) {
              page = page + 1;
              getHashData(page, hash);
            }
          }
        });
      }
    });
  }

  Future getHashesData(searchKeyword) async {
    if (showLoadMoreHashTags) {
      videoRepo.userVideoObj.value.userId = 0;
      videoRepo.userVideoObj.value.videoId = 0;
      videoRepo.userVideoObj.value.hashTag = "";
      videoRepo.userVideoObj.notifyListeners();

      showLoader.value = true;
      showLoader.notifyListeners();
      hashScrollController = new ScrollController();
      hashRepo.getHashesData(hashesPage, searchKeyword).then((value) {
        if (value != null) {
          showLoader.value = false;
          showLoader.notifyListeners();
          if (value.length == 0) {
            showLoadMoreHashTags = false;
          }
        }
      });
    }
  }

  Future getUsersData(searchKeyword) async {
    if (showLoadMoreHashTags) {
      videoRepo.userVideoObj.value.userId = 0;
      videoRepo.userVideoObj.value.videoId = 0;
      videoRepo.userVideoObj.value.hashTag = "";
      videoRepo.userVideoObj.notifyListeners();
      showLoader.value = true;
      showLoader.notifyListeners();
      userScrollController = new ScrollController();
      hashRepo.getUsersData(usersPage, searchKeyword).then((value) {
        if (value != null) {
          showLoader.value = false;
          showLoader.notifyListeners();
          if (value.length == 0) {
            showLoadMoreUsers = false;
          }
        }
      });
    }
  }

  Future getVideosData(searchKeyword) async {
    if (showLoadMoreVideos) {
      videoRepo.userVideoObj.value.userId = 0;
      videoRepo.userVideoObj.value.videoId = 0;
      videoRepo.userVideoObj.value.hashTag = "";
      videoRepo.userVideoObj.notifyListeners();
      showLoader.value = true;
      showLoader.notifyListeners();
      videoScrollController = new ScrollController();
      hashRepo.getVideosData(videosPage, searchKeyword).then((value) {
        if (value != null) {
          showLoader.value = false;
          showLoader.notifyListeners();
          if (value.length > 0) {
            showLoadMoreVideos = false;
          }
        }
      });
    }
  }

  Future getSearchData(page) async {
    videoRepo.userVideoObj.value.userId = 0;
    videoRepo.userVideoObj.value.videoId = 0;
    videoRepo.userVideoObj.value.hashTag = "";
    videoRepo.userVideoObj.notifyListeners();

    showLoader.value = true;
    showLoader.notifyListeners();
    scrollController = new ScrollController();
    SearchModel value = await hashRepo.getSearchData(page, searchKeyword);
    showLoader.value = false;
    showLoader.notifyListeners();
    if (value.hashTags.length < 10) {
      // setState(() {
      showLoadMoreHashTags = false;
      // });
    } else {
      hashScrollController = new ScrollController();
      hashScrollController.addListener(() {
        if (hashScrollController.position.pixels >= hashScrollController.position.maxScrollExtent - 100) {
          if (showLoadMoreHashTags) {
            getHashesData(searchKeyword);
            // setState(() {
            hashesPage++;
            // });
          }
        }
      });
    }
    if (value.users.length < 10) {
      // setState(() {
      showLoadMoreUsers = false;
      // });
    } else {
      userScrollController = new ScrollController();
      userScrollController.addListener(() {
        if (userScrollController.position.pixels >= userScrollController.position.maxScrollExtent - 100) {
          if (showLoadMoreUsers) {
            getUsersData(searchKeyword);
            // setState(() {
            usersPage++;
            // });
          }
        }
      });
    }
    if (value.videos.length < 10) {
      // setState(() {
      showLoadMoreVideos = false;
      // });
    } else {
      videoScrollController = new ScrollController();
      videoScrollController.addListener(() {
        if (videoScrollController.position.pixels >= videoScrollController.position.maxScrollExtent - 100) {
          if (showLoadMoreVideos) {
            getVideosData(searchKeyword);
            // setState(() {
            videosPage++;
            // });
          }
        }
      });
    }
  }
}
