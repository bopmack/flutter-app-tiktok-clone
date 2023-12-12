import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:helpers/helpers/transition.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:video_player/video_player.dart';

import '../helpers/app_config.dart' as config;
import '../helpers/helper.dart';
import '../models/videos_model.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../services/CacheManager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Video videoObj;
  VideoPlayerController? videoController;
  Future<void>? initializeVideoPlayerFuture;
  VideoPlayerWidget(this.videoController, this.videoObj, this.initializeVideoPlayerFuture);
  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends StateMVC<VideoPlayerWidget> with TickerProviderStateMixin {
  int chkVideo = 0;
  late VoidCallback listener;
  late AnimationController _animationController;
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  bool showAnim = false;
  @override
  void initState() {
    scaffoldKey = new GlobalKey<ScaffoldState>(debugLabel: widget.videoObj.videoId.toString());
    listener = () {
      if (widget.videoController!.value.hasError) {
        print("videoPlayerError");
        print(widget.videoController!.value.errorDescription);
        widget.videoController!.dispose();
      } else {
        if (widget.videoController!.value.position.inSeconds == 5 || widget.videoController!.value.position.inSeconds == widget.videoController!.value.duration.inSeconds) {
          widget.videoController!.removeListener(listener);
          chkVideo = 1;
          videoRepo.incVideoViews(widget.videoObj);
        } else {
          return;
        }
      }
    };
    checkVideoController();
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    print("Video Player Widget disposed");
    // widget.videoController!.dispose();
    _animationController.dispose();
    super.dispose();
  }

  checkVideoController() async {
    // try {
    if (widget.videoController!.hasListeners) {
      if (widget.videoController!.value.isInitialized) {
        widget.videoController!.play();
        setState(() {
          videoRepo.homeCon.value.onTap = false;
        });
      }
    } else {}
    /*} catch (e) {
      print("error play=");
      final fileInfo = await CustomCacheManager.instance.getFileFromCache(widget.videoObj.url);
      VideoPlayerController controller;
      controller = VideoPlayerController.network(widget.videoObj.url);
      widget.videoController = controller;
      if (fileInfo == null || fileInfo.file == null) {
        unawaited(CustomCacheManager.instance.downloadFile(widget.videoObj.url).whenComplete(() => print('VideoPLayerFile saved video url ${widget.videoObj.url}')).onError((error, stackTrace) {
          print(error);
          return Future.value(fileInfo);
        }));
      } else {
        controller = VideoPlayerController.file(fileInfo.file);
        widget.videoController = controller;
      }
      widget.initializeVideoPlayerFuture = widget.videoController!.initialize();
      videoRepo.homeCon.value.videoControllers[widget.videoObj.url] = widget.videoController;

      videoRepo.homeCon.value.initializeVideoPlayerFutures[widget.videoObj.url] = widget.initializeVideoPlayerFuture!;
      videoRepo.homeCon.notifyListeners();
      if (widget.videoController!.value.isInitialized) {
        widget.videoController!.play();

        setState(() {
          videoRepo.homeCon.value.onTap = false;
        });
      }
    }*/
    if (chkVideo == 0) {
      widget.videoController!.addListener(listener);
    } else {
      widget.videoController!.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: settingRepo.setting.value.bgColor,
      body: FutureBuilder(
          future: widget.initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showAnim = true;
                      videoRepo.homeCon.value.onTap = true;
                      if (widget.videoController!.value.isPlaying) {
                        _animationController.reverse();
                        widget.videoController!.pause();
                      } else {
                        _animationController.forward();
                        widget.videoController!.play();
                      }
                    });
                    print("showAnim $showAnim");
                  },
                  child: AnimatedOpacity(
                    opacity: snapshot.connectionState == ConnectionState.done ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 0),
                    // The green box must be a child of the AnimatedOpacity widget.
                    child: Container(
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Stack(
                            children: <Widget>[
                              Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height,
                                    maxWidth: MediaQuery.of(context).size.width,
                                  ),
                                  child: SizedBox.expand(
                                    child: FittedBox(
                                      fit: widget.videoController!.value.size.height > widget.videoController!.value.size.width ? BoxFit.fitHeight : BoxFit.fitWidth,
                                      child: SizedBox(
                                        width: widget.videoController!.value.size.width,
                                        height: widget.videoController!.value.size.height,
                                        child: VideoPlayer(widget.videoController!),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              /*Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: widget.videoController!.value.isPlaying
                                        ? Colors.transparent
                                        : (!videoRepo.homeCon.value.onTap)
                                            ? Colors.transparent
                                            : settingRepo.setting.value.dashboardIconColor,
                                    size: 80,
                                  ),
                                ),
                              ),*/
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (_, __) => OpacityTransition(
                                    duration: Duration(milliseconds: 300),
                                    visible: !widget.videoController!.value.isPlaying && showAnim,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: settingRepo.setting.value.dashboardIconColor!, width: 2.0),
                                          borderRadius: BorderRadius.circular(50.0),
                                        ),
                                        child: AnimatedIcon(
                                          icon: AnimatedIcons.play_pause,
                                          progress: _animationController,
                                          size: 50,
                                          color: settingRepo.setting.value.dashboardIconColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  height: widget.videoController!.value.size.height * 0.4,
                                  width: config.App(scaffoldKey.currentContext).appWidth(100),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black38,
                                        Colors.black26,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      showAnim = true;
                      videoRepo.homeCon.value.onTap = true;
                      if (widget.videoController!.value.isPlaying) {
                        _animationController.reverse();
                        widget.videoController!.pause();
                      } else {
                        _animationController.forward();
                        widget.videoController!.play();
                      }
                    });
                  },
                  child: AnimatedOpacity(
                    opacity: snapshot.connectionState != ConnectionState.done ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    // The green box must be a child of the AnimatedOpacity widget.
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height,
                              maxWidth: MediaQuery.of(context).size.width,
                            ),
                            child: SizedBox.expand(
                              child: Container(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      widget.videoObj.videoThumbnail,
                                      cacheManager: CustomCacheManager.instance,
                                    ),
                                    fit: widget.videoObj.isWide ? BoxFit.fitWidth : BoxFit.fitHeight,
                                  ),
                                ),
                                child: Helper.showLoaderSpinner(Colors.transparent),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            height: config.App(scaffoldKey.currentContext).appHeight(40),
                            width: config.App(scaffoldKey.currentContext).appWidth(100),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black38,
                                  Colors.black26,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          }),
    );
  }
}
