import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../repositories/hash_repository.dart' as hashRepo;

class BannerAdWidget extends StatefulWidget {
  BannerAdWidget();

  // final AdSize size;

  @override
  State<StatefulWidget> createState() => BannerAdState();
}

class BannerAdState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  final Completer<BannerAd> bannerCompleter = Completer<BannerAd>();

  bool _bannerAdIsLoaded = false;
  AdSize? size;
  @override
  void initState() {
    super.initState();
  }

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(int.parse(MediaQuery.of(context).size.width.round().toString()));
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid ? hashRepo.adsData.value['android_banner_app_id'] : hashRepo.adsData.value['ios_banner_app_id'],
      request: AdRequest(),
      size: size!,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
          _bannerAdIsLoaded = true;
          });
          print('BannerAd loaded. 111');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          print('$BannerAd failedToLoad: $error');
        },
        onAdOpened: (Ad ad) => print('$BannerAd onAdOpened.'),
        onAdClosed: (Ad ad) => print('$BannerAd onAdClosed.'),
      ),
    )..load();
    // Future<void>.delayed(Duration(seconds: 1), () => _bannerAd.load());
  }

  @override
  void dispose() {
    super.dispose();
    _bannerAd!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? bannerAd = _bannerAd;
    return _bannerAdIsLoaded && bannerAd != null
        ? Container(
            width: bannerAd.size.width.toDouble(),
            height: bannerAd.size.height.toDouble(),
            color: Colors.black,
            child: AdWidget(ad: bannerAd),
          )
        : Container();
  }
}
