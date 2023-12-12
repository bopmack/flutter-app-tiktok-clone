import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:pedantic/pedantic.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import "package:velocity_x/velocity_x.dart";
import 'package:video_player/video_player.dart';

// import 'package:video_trimmer/video_trimmer.dart';

import '../controllers/video_recorder_controller.dart';
import '../models/sound_model.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/sound_repository.dart' as soundRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../views/sound_list.dart';
import '../views/video_submit.dart';
import '../widgets/MarqueWidget.dart';

class VideoRecorder extends StatefulWidget {
  VideoRecorder({
    Key? key,
  }) {}
  @override
  _VideoRecorderState createState() {
    return _VideoRecorderState();
  }
}

class _VideoRecorderState extends StateMVC<VideoRecorder> with TickerProviderStateMixin {
  VideoRecorderController _con = VideoRecorderController();

  _VideoRecorderState() : super(VideoRecorderController()) {
    _con = VideoRecorderController();
  }

  @override
  void dispose() {
    print("Video Recorder Dispose");

    _con.controller!.dispose();
    try {
      if (_con.animationController != null) _con.animationController!.dispose();
    } catch (e) {}
    if (_con.videoController != null) _con.videoController!.dispose();

    if (_con.videoEditorController != null) {
      _con.videoEditorController!.dispose();
      _con.videoEditorController!.video.dispose();
    }
    if (_con.previewVideoController != null) _con.previewVideoController!.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("didChangeAppLifecycleState");
    // App state changed before we got the chance to initialize.
    if (!_con.controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        _con.onCameraSwitched(_con.controller!.description);
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    _con.getTimeLimits();
    _con.initCamera();
    if (soundRepo.currentSound.value.soundId > 0) {
      _con.saveAudio(soundRepo.currentSound.value.url);
    }
    super.initState();
    _con.animationController = AnimationController(vsync: this, duration: Duration(seconds: _con.seconds))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _con.animationController!.repeat(reverse: !_con.reverse);
          setState(() {
            _con.reverse = !_con.reverse;
          });
        }
      });

    _con.sizeAnimation = Tween<double>(begin: 70.0, end: 80.0).animate(_con.animationController!);
    _con.animationController!.forward();

    unawaited(_con.loadWatermark());
  }

  Widget _thumbnailWidget() {
    final VideoPlayerController? localVideoController = _con.videoController;

    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: _con.videoController == null
          ? Container()
          : Stack(children: <Widget>[
              SizedBox.expand(
                child: (_con.videoController == null)
                    ? Container()
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _con.videoController!.value.size.width,
                              height: _con.videoController!.value.size.height,
                              child: Center(
                                child: Container(
                                  child: Center(
                                    child: AspectRatio(aspectRatio: localVideoController!.value.size != null ? localVideoController.value.aspectRatio : 1.0, child: VideoPlayer(localVideoController)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 50,
                right: 20,
                child: RawMaterialButton(
                  onPressed: () {
                    _con.videoController!.pause();
                    _con.videoController!.dispose();

                    super.dispose();
                    _con.controller!.dispose();
                    try {
                      if (_con.animationController != null) _con.animationController!.dispose();
                    } catch (e) {}
                    if (_con.videoController != null) _con.videoController!.dispose();

                    if (_con.videoEditorController != null) {
                      _con.videoEditorController!.dispose();
                      _con.videoEditorController!.video.dispose();
                    }
                    if (_con.previewVideoController != null) _con.previewVideoController!.dispose();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoSubmit(
                          thumbPath: _con.thumbPath,
                          videoPath: _con.videoPath,
                          gifPath: _con.gifPath,
                        ),
                      ),
                    );
                  },
                  elevation: 2.0,
                  fillColor: Colors.white,
                  child: Icon(
                    Icons.check_circle,
                    size: 35.0,
                  ),
                  padding: EdgeInsets.all(15.0),
                  shape: CircleBorder(),
                ),
              ),
              Positioned(
                bottom: 50,
                left: 20,
                child: RawMaterialButton(
                  onPressed: () {
                    _con.videoController!.pause();
                    soundRepo.currentSound = new ValueNotifier(SoundData(soundId: 0, title: ""));
                    soundRepo.currentSound.notifyListeners();
                    videoRepo.homeCon.value.showFollowingPage.value = false;
                    videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                    videoRepo.homeCon.value.getVideos();
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  elevation: 2.0,
                  fillColor: Colors.white,
                  child: Icon(
                    Icons.close,
                    size: 35.0,
                  ),
                  padding: EdgeInsets.all(15.0),
                  shape: CircleBorder(),
                ),
              ),
            ]),
    );
  }

  static showLoaderSpinner() {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    _con.cameraPreview.addListener(() {
      if (_con.cameraPreview.value == true) {
        setState(() {});
      }
    });
    var size = MediaQuery.of(context).size;
    if (size != null) {
      var deviceRatio = size.width / size.height;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.black54),
      );
      return ModalProgressHUD(
        progressIndicator: showLoaderSpinner(),
        inAsyncCall: _con.showLoader,
        child: WillPopScope(
          onWillPop: () async => _con.willPopScope(context),
          child: Scaffold(
            backgroundColor: settingRepo.setting.value.bgColor,
            key: _con.scaffoldKey,
            body: SafeArea(
              child: Stack(
                children: <Widget>[
                  GestureDetector(
                    child: Center(
                      child: _cameraPreviewWidget(),
                    ),
                    onDoubleTap: () {
                      // _con.onSwitchCamera();
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: _con.startTimerTiming,
                    builder: (context, int counter, _) {
                      return counter > 0
                          ? Center(
                              child: Container(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                color: settingRepo.setting.value.textColor!.withOpacity(0.3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      '$counter',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 60,
                                        color: settingRepo.setting.value.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SizedBox();
                    },
                  ),
                  Positioned(
                    bottom: 35,
                    left: 85,
                    child: _cameraFlashRowWidget(),
                  ),
                  Positioned(
                    bottom: 20,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _captureControlRowWidget(),
                      ),
                    ),
                  ),
                  (_con.controller == null || !_con.controller!.value.isInitialized || !_con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          bottom: 35,
                          left: 0,
                          child: _cameraTogglesRowWidget(),
                        )
                      : Container(),
                  (_con.controller == null || !_con.controller!.value.isInitialized || !_con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          bottom: 110,
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            child: Center(
                              child: getTimerLimit(),
                            ),
                          ),
                        )
                      : Container(),
                  (_con.controller == null || !_con.controller!.value.isInitialized || !_con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          top: 80,
                          right: 15,
                          child: Container(
                            child: Center(
                              child: getStartTimer(),
                            ),
                          ),
                        )
                      : Container(),
                  (_con.showProgressBar)
                      ? Positioned(
                          top: 10,
                          child: ValueListenableBuilder(
                              valueListenable: _con.videoProgressPercent,
                              builder: (context, double videoProgressPercent, _) {
                                return LinearPercentIndicator(
                                  width: MediaQuery.of(context).size.width,
                                  lineHeight: 5.0,
                                  animationDuration: 100,
                                  percent: videoProgressPercent,
                                  progressColor: Colors.pink,
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  // progressColor: Colors.black,
                                );
                              }),
                        )
                      : Container(),
                  (_con.controller == null || !_con.controller!.value.isInitialized || !_con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          top: 30,
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: GestureDetector(
                                child: SizedBox(
                                  width: 140.0,
                                  child: MarqueeWidget(
                                    direction: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          soundRepo.currentSound.value.title == null || soundRepo.currentSound.value.title == "" ? "Select Sound " : soundRepo.currentSound.value.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Icon(
                                          Icons.queue_music,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SoundList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : Container(),
                  (_con.controller != null && _con.controller!.value.isInitialized && _con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          bottom: 42,
                          right: 90,
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: SizedBox.fromSize(
                                size: Size(
                                  30,
                                  30,
                                ), // button width and height
                                child: ClipOval(
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        splashColor: Colors.pinkAccent, // splash color
                                        onTap: () {
                                          setState(() {
                                            _con.reverse = _con.reverse;
                                          });
                                          if (!_con.videoRecorded) {
                                            _con.onResumeButtonPressed(context);
                                            _con.animationController!.forward();
                                          } else {
                                            _con.onPauseButtonPressed(context);
                                            _con.animationController!.stop();
                                          }
                                        },
                                        child: Container(
                                            color: Colors.white,
                                            width: 30,
                                            height: 30,
                                            child: SvgPicture.asset(
                                              !_con.videoRecorded ? 'assets/icons/play.svg' : 'assets/icons/pause.svg',
                                              width: 30,
                                              height: 30,
                                              color: settingRepo.setting.value.accentColor,
                                            ).centered()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(),
                  (_con.controller == null || !_con.controller!.value.isInitialized || !_con.controller!.value.isRecordingVideo)
                      ? Positioned(
                          bottom: 35,
                          right: 20,
                          child: InkWell(
                            child: SvgPicture.asset(
                              'assets/icons/add_photo.svg',
                              width: 40,
                              color: settingRepo.setting.value.iconColor,
                            ),
                            onTap: () {
                              print("uploadGalleryVideo(");
                              _con.uploadGalleryVideo();
                            },
                          ),
                        )
                      : Container(),
                  (_con.isUploading == true)
                      ? Container(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                          ),
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black87,
                              ),
                              width: 200,
                              height: 170,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: <Widget>[
                                    Center(
                                      child: CircularPercentIndicator(
                                        progressColor: Colors.pink,
                                        percent: _con.uploadProgress.value,
                                        radius: 120.0,
                                        lineWidth: 8.0,
                                        circularStrokeCap: CircularStrokeCap.round,
                                        center: Text(
                                          (_con.uploadProgress.value * 100).toStringAsFixed(2) + "%",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(),
                  _con.controller != null && _con.controller!.value.isInitialized && !_con.controller!.value.isRecordingVideo
                      ? Positioned(
                          top: 30,
                          left: 10,
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SizedBox(
                                width: 35,
                                child: ValueListenableBuilder(
                                    valueListenable: soundRepo.mic,
                                    builder: (context, bool enableMic, _) {
                                      return InkWell(
                                        child: SizedBox(
                                          width: 35,
                                          child: enableMic
                                              ? Image.asset(
                                                  "assets/icons/microphone.png",
                                                  height: 30,
                                                )
                                              : Image.asset(
                                                  "assets/icons/microphone-mute.png",
                                                  height: 30,
                                                ),
                                        ),
                                        onTap: () {
                                          soundRepo.mic.value = enableMic ? false : true;
                                          soundRepo.mic.notifyListeners();
                                          _con.onCameraSwitched(_con.cameras[_con.selectedCameraIdx]).then((void v) {});
                                        },
                                      );
                                    }),
                              ),
                            ),
                          ),
                        )
                      : Container(),
                  _thumbnailWidget(),
                  _con.videoController == null
                      ? Positioned(
                          top: 30,
                          right: 20,
                          child: GestureDetector(
                            onTap: () {
                              _con.willPopScope(context);
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.close,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 0,
                        ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Center(
        child: CircularProgressIndicator(
          valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = _con.controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text(
        'Loading..',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _con.pointers++,
        onPointerUp: (_) => _con.pointers--,
        child: CameraPreview(
          _con.controller!,
          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _con.handleScaleStart,
              onScaleUpdate: _con.handleScaleUpdate,
              onTapDown: (details) => _con.onViewFinderTap(details, constraints),
            );
          }),
        ),
      );
    }
  }

  Widget _cameraTogglesRowWidget() {
    if (_con.cameras == null) {
      return Row();
    }
    return ValueListenableBuilder(
      valueListenable: _con.disableFlipButton,
      builder: (context, bool disableButton, _) {
        return (!disableButton)
            ? InkWell(
                child: SvgPicture.asset(
                  'assets/icons/flip.svg',
                  width: 30,
                  color: settingRepo.setting.value.iconColor,
                ).pOnly(left: 25),
                onTap: () {
                  _con.onSwitchCamera();
                },
              )
            : Container();
      },
    );
  }

  Widget _cameraFlashRowWidget() {
    return Row();
  }

  Widget _captureControlRowWidget() {
    final CameraController? cameraController = _con.controller;
    if (cameraController == null) {
      return Container();
    }
    return cameraController.value.isInitialized
        ? !cameraController.value.isRecordingVideo && !_con.isProcessing
            ? ClipOval(
                child: Container(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Center(
                          child: InkWell(
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            onTap: () {
                              setState(() {});
                              _con.onRecordButtonPressed(context);
                              _con.controller!.notifyListeners();
                            },
                            onDoubleTap: () {
                              if (cameraController != null && cameraController.value.isInitialized && !cameraController.value.isRecordingVideo) {
                                print("Camera Testing");
                              } else {
                                print("else Camera Testing");
                              }
                            },
                            child: SvgPicture.asset(
                              "assets/icons/create-video.svg",
                              width: 70,
                              height: 70,
                              color: settingRepo.setting.value.accentColor,
                            ),
                          ),
                        ), // icon
                      ],
                    ),
                  ),
                ),
              )
            : AnimatedBuilder(
                animation: _con.sizeAnimation,
                builder: (context, child) => SizedBox.fromSize(
                  size: Size(_con.sizeAnimation.value, _con.sizeAnimation.value), // button width and height
                  child: GestureDetector(
                    onTap: () {
                      setState(() {});
                      _con.onStopButtonPressed();
                      _con.controller!.notifyListeners();
                    },
                    onDoubleTap: () {
                      if (cameraController.value.isInitialized && !cameraController.value.isRecordingVideo) {
                        print("Camera Testing");
                      } else {
                        print("else Camera Testing");
                      }
                    },
                    child: SvgPicture.asset(
                      "assets/icons/video-stop.svg",
                      width: 50,
                      height: 50,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              )
        : Container();
  }

  Widget getTimerLimit() {
    List<Widget> list = <Widget>[];
    return ValueListenableBuilder(
        valueListenable: videoRepo.selectedVideoLength,
        builder: (context, double videoLength, _) {
          return ValueListenableBuilder(
              valueListenable: _con.videoTimerLimit,
              builder: (context, List<double> timers, _) {
                timers.length = timers.length > 5 ? 5 : timers.length;
                list = <Widget>[];
                if (timers.length > 0) {
                  for (var i = 0; i < timers.length; i++) {
                    list.add(
                      InkWell(
                        onTap: () {
                          if (videoLength != timers[i].toDouble()) {
                            videoRepo.selectedVideoLength.value = timers[i] > 300 ? 300 : timers[i];
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 9),
                          height: 30,
                          constraints: BoxConstraints(
                            minWidth: 30,
                          ),
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: (videoLength == timers[i]) ? settingRepo.setting.value.accentColor : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: (videoLength == timers[i]) ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white70, width: 0),
                          ),
                          child: Center(
                            child: Text(
                              "${timers[i].toInt() > 300 ? 300 : timers[i].toInt()}s",
                              style: TextStyle(
                                color: (videoLength == timers[i]) ? settingRepo.setting.value.buttonTextColor : Colors.black,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 70,
                      child: timers.length > 0
                          ? list.length > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: list,
                                )
                              : Container()
                          : Container(),
                    ),
                  );
                } else {
                  list.add(Container());
                  return Container();
                }
              });
        });
  }

  Widget getStartTimer() {
    List<Widget> list = <Widget>[];
    return !_con.videoRecorded
        ? ValueListenableBuilder(
            valueListenable: _con.showTimerTimings,
            builder: (context, bool showTimer, _) {
              return (!showTimer)
                  ? Stack(
                      children: [
                        InkWell(
                          child: SvgPicture.asset(
                            'assets/icons/timer.svg',
                            width: 35,
                            color: settingRepo.setting.value.iconColor,
                          ),
                          onTap: () {
                            _con.showTimerTimings.value = true;
                            _con.showTimerTimings.notifyListeners();
                          },
                        ),
                        ValueListenableBuilder(
                            valueListenable: _con.startTimerTiming,
                            builder: (context, int time, _) {
                              return time > 0
                                  ? Positioned(
                                      bottom: 0,
                                      left: 0,
                                      // width: 15,
                                      child: Container(
                                          height: 15,
                                          padding: EdgeInsets.all(1),
                                          decoration: BoxDecoration(
                                            color: settingRepo.setting.value.buttonColor,
                                            borderRadius: BorderRadius.circular(6),
                                            // border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: "${time}s".text.textStyle(TextStyle(fontSize: 8, color: settingRepo.setting.value.buttonTextColor, fontWeight: FontWeight.bold)).make().centered()),
                                    )
                                  : SizedBox();
                            }),
                      ],
                    )
                  : ValueListenableBuilder(
                      valueListenable: videoRepo.selectedVideoLength,
                      builder: (context, double videoLength, _) {
                        return ValueListenableBuilder(
                            valueListenable: _con.startTimerLimits,
                            builder: (context, List<int> timers, _) {
                              timers.length = timers.length > 5 ? 5 : timers.length;
                              list = <Widget>[];
                              if (timers.length > 0) {
                                for (var i = 0; i < timers.length; i++) {
                                  list.add(
                                    InkWell(
                                      onTap: () {
                                        _con.startTimerTiming.value = timers[i];
                                        _con.startTimerTiming.notifyListeners();
                                        _con.showTimerTimings.value = false;
                                        _con.showTimerTimings.notifyListeners();
                                      },
                                      child: Container(
                                        margin: EdgeInsets.symmetric(vertical: 3),
                                        height: 30,
                                        width: 30,
                                        constraints: BoxConstraints(
                                          minWidth: 30,
                                        ),
                                        padding: EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: (videoLength == timers[i]) ? settingRepo.setting.value.accentColor : Colors.white.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(6),
                                          border: (videoLength == timers[i]) ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white70, width: 0),
                                        ),
                                        child: Center(
                                          child: timers[i] == 0
                                              ? Icon(
                                                  Icons.close,
                                                  size: 12,
                                                )
                                              : Text(
                                                  "${timers[i].toInt()}s",
                                                  style: TextStyle(
                                                    color: (videoLength == timers[i]) ? settingRepo.setting.value.buttonTextColor : Colors.black,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Center(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        // height: 100,
                                        child: timers.length > 0
                                            ? list.length > 0
                                                ? Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: list,
                                                  )
                                                : Container()
                                            : Container(),
                                      ),
                                      Stack(
                                        children: [
                                          InkWell(
                                            child: SvgPicture.asset(
                                              'assets/icons/timer.svg',
                                              width: 35,
                                              color: settingRepo.setting.value.iconColor,
                                            ),
                                            onTap: () {
                                              _con.showTimerTimings.value = false;
                                              _con.showTimerTimings.notifyListeners();
                                            },
                                          ),
                                          ValueListenableBuilder(
                                              valueListenable: _con.startTimerTiming,
                                              builder: (context, int time, _) {
                                                return time > 0
                                                    ? Positioned(
                                                        bottom: 0,
                                                        left: 0,
                                                        // width: 15,
                                                        child: Container(
                                                            height: 15,
                                                            padding: EdgeInsets.all(1),
                                                            decoration: BoxDecoration(
                                                              color: settingRepo.setting.value.buttonColor,
                                                              borderRadius: BorderRadius.circular(6),
                                                              // border: Border.all(color: Colors.white, width: 2),
                                                            ),
                                                            child: "${time}s"
                                                                .text
                                                                .textStyle(
                                                                  TextStyle(
                                                                    fontSize: 8,
                                                                    color: settingRepo.setting.value.buttonTextColor,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                )
                                                                .make()
                                                                .centered()),
                                                      )
                                                    : SizedBox();
                                              }),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              } else {
                                list.add(Container());
                                return Container();
                              }
                            });
                      });
            })
        : SizedBox();
  }
}

class VideoRecorderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return MaterialApp(
      home: VideoRecorder(),
    );
  }
}

Future<void> main() async {
  runApp(VideoRecorderApp());
}
