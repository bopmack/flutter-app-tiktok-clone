import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffprobe_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:helpers/helpers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:stories_editor/stories_editor.dart';
import "package:velocity_x/velocity_x.dart";
import 'package:video_player/video_player.dart';

import '../helpers/global_keys.dart';
import '../helpers/helper.dart';
import '../models/sound_model.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/sound_repository.dart' as soundRepo;
import '../repositories/user_repository.dart' as userRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../views/video_editor_views.dart';
import '../views/video_submit.dart';
import '../widgets/video_editor/video_editor.dart';
import 'dashboard_controller.dart';

class VideoRecorderController extends ControllerMVC {
  DashboardController homeCon = DashboardController();
  CameraController? controller;
  String videoPath = "";
  String audioFile = "";
  String description = "";
  List<CameraDescription> cameras = [];
  int selectedCameraIdx = 0;
  bool videoRecorded = false;
  GlobalKey<FormState> key = new GlobalKey();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldState> videoEditorViewKey = GlobalKey<ScaffoldState>();
  // final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
  bool showRecordingButton = false;
  ValueNotifier<bool> isUploading = new ValueNotifier(false);
  ValueNotifier<bool> disableFlipButton = new ValueNotifier(false);
  bool isProcessing = false;
  ValueNotifier<double> uploadProgress = new ValueNotifier(0);
  ValueNotifier<Text> videoText = new ValueNotifier(Text(""));
  bool saveLocally = true;
  VideoPlayerController? videoController;
  VoidCallback videoPlayerListener = () {};
  String thumbFile = "";
  String gifFile = "";
  String watermark = "";
  int userId = 0;
  PanelController pc1 = new PanelController();
  String appToken = "";
  final assetsAudioPlayer = AssetsAudioPlayer();
  String audioFileName = "";
  int audioId = 0;
  int videoId = 0;
  bool showLoader = false;
  bool isPublishPanelOpen = false;
  bool isVideoRecorded = false;
  ValueNotifier<double> videoProgressPercent = new ValueNotifier(0);

  bool showProgressBar = false;
  double progress = 0.0;
  late GlobalKey textOverlayKey;
  late Timer timer = Timer.periodic(new Duration(milliseconds: 100), (timer) {
    videoProgressPercent.value += 1 / (videoRepo.selectedVideoLength.value * 10);
    videoProgressPercent.notifyListeners();
    if (videoProgressPercent.value >= 1) {
      isProcessing = true;
      videoProgressPercent.value = 1;
      videoProgressPercent.notifyListeners();
      timer.cancel();
      onStopButtonPressed();
    }
  });
  String responsePath = "";
  // double videoLength = 15.0;
  bool cameraCrash = false;
  AnimationController? animationController;
  late Animation sizeAnimation;
  bool reverse = false;
  bool isRecordingPaused = false;
  int seconds = 1;
  int privacy = 0;
  String thumbPath = "";
  String gifPath = "";
  ValueNotifier<DateTime> endShift = ValueNotifier(DateTime.now());
  DateTime pauseTime = DateTime.now();
  DateTime playTime = DateTime.now();
  ValueNotifier<List<double>> videoTimerLimit = new ValueNotifier([]);
  ValueNotifier<bool> cameraPreview = new ValueNotifier(false);
  int pointers = 0;
  bool enableAudio = true;
  double minAvailableExposureOffset = 0.0;
  double maxAvailableExposureOffset = 0.0;
  double currentExposureOffset = 0.0;
  double minAvailableZoom = 1.0;
  double maxAvailableZoom = 1.0;
  double currentScale = 1.0;
  double baseScale = 1.0;
  double textWidgetHeight = 0.0;
  double textWidgetWidth = 0.0;
  var cropWidgetKey = GlobalKey();
  String textFilterImagePath = "";
  TransformationController? transformationController;
  ValueNotifier<bool> showTextFilter = new ValueNotifier(false);

  bool _firstStat = true;

  ValueNotifier<bool> showTimerTimings = ValueNotifier(false);
  ValueNotifier<int> startTimerTiming = ValueNotifier(0);
  ValueNotifier<List<int>> startTimerLimits = new ValueNotifier([0, 3, 10]);

  late Timer waitTimer;

  VideoEditorController? videoEditorController;

  String exportText = "";

  bool exported = false;

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
  final double height = 60;
  VideoPlayerController? previewVideoController;
  ValueNotifier<bool> showEditorDone = ValueNotifier(false);

  @override
  void dispose() {
    print("Video Recorder MVC Controller Dispose");
    if (animationController != null) animationController!.dispose();
    if (videoController != null) videoController!.dispose();
    if (controller != null) controller!.dispose();

    if (videoEditorController != null) {
      videoEditorController!.dispose();
      videoEditorController!.video.dispose();
    }
    if (previewVideoController != null) previewVideoController!.dispose();
    super.dispose();
  }

  initCamera() {
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        setState(() {
          selectedCameraIdx = 0;
          print(1111);
        });

        onCameraSwitched(cameras[selectedCameraIdx]).then((void v) {});
      }
    }).catchError((err) {
      print('Error: $err.code\nError Message: $err.message');
    });
  }

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use
    ScaffoldMessenger.of(GlobalVariable.navState.currentContext!).showSnackBar(SnackBar(content: Text(message)));
  }

/*  void _handleScaleStart(ScaleStartDetails details) {
    baseScale = currentScale;
  }*/

  Future<void> handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || pointers != 2) {
      return;
    }

    currentScale = (baseScale * details.scale).clamp(minAvailableZoom, maxAvailableZoom);

    await controller!.setZoomLevel(currentScale);
  }

  void handleScaleStart(ScaleStartDetails details) {
    baseScale = currentScale;
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (cameraController.value.hasError) {
        showInSnackBar('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        // The exposure mode is currently not supported on the web.
        ...(!kIsWeb
            ? [cameraController.getMinExposureOffset().then((value) => minAvailableExposureOffset = value), cameraController.getMaxExposureOffset().then((value) => maxAvailableExposureOffset = value)]
            : []),
        cameraController.getMaxZoomLevel().then((value) => maxAvailableZoom = value),
        cameraController.getMinZoomLevel().then((value) => minAvailableZoom = value),
      ]);
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  void _showCameraException(CameraException e) {
    print("${e.code} ${e.description}");
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  String? validateDescription(String? value) {
    if (value!.length == 0) {
      return "Description is required!";
    } else {
      return null;
    }
  }

  loadWatermark() {
    videoRepo.getWatermark().then((value) async {
      if (value != '') {
        var file = await DefaultCacheManager().getSingleFile(value);
        watermark = file.path;
        videoRepo.watermarkUri.value = watermark;
        videoRepo.watermarkUri.notifyListeners();
      }
    });
  }

  Future<void> onCameraSwitched(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    if (audioFileName == "") {
      controller = CameraController(
        cameraDescription,
        ResolutionPreset.veryHigh,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: soundRepo.mic.value ? true : false,
        // enableAudio: true,
      );
    } else {
      controller = CameraController(
        cameraDescription,
        ResolutionPreset.veryHigh,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: soundRepo.mic.value ? true : false,
        // enableAudio: true,
      );
    }
    try {
      await controller!.initialize();
      // await controller!.setFlashMode(FlashMode.off);
      await controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      print("Expdddd:" + e.toString());
      setState(() {});
      // showCameraException(e, GlobalVariable.navState.currentContext);
    }
    setState(() {});
    cameraPreview.value = true;
    cameraPreview.notifyListeners();
  }

  Widget dialogContent(BuildContext context) {
    return Container(
      child: Stack(
        children: <Widget>[
          Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: new Text("Camera Error", style: TextStyle(fontSize: 20.0, color: settingRepo.setting.value.textColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: new Text("Camera Stopped Wroking !!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.0,
                          color: settingRepo.setting.value.textColor,
                        )),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: settingRepo.setting.value.accentColor,
                    ),
                    child: Center(
                      child: Text(
                        'Exit',
                        style: TextStyle(
                          color: settingRepo.setting.value.textColor,
                          fontSize: 20,
                          fontFamily: 'RockWellStd',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showCameraException(CameraException e, BuildContext context) {
    setState(() {
      cameraCrash = true;
    });
    AwesomeDialog(
      dialogBackgroundColor: settingRepo.setting.value.buttonColor,
      context: GlobalVariable.navState.currentContext!,
      animType: AnimType.SCALE,
      dialogType: DialogType.WARNING,
      body: dialogContent(context),
      btnOkText: "Close",
    )..show();
  }

  Future<void> onSwitchCamera() async {
    disableFlipButton.value = true;
    disableFlipButton.notifyListeners();
    selectedCameraIdx = selectedCameraIdx == 0 ? 1 : 0;
    print("selectedCameraIdx $selectedCameraIdx");
    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    await onCameraSwitched(selectedCamera);
    setState(() {
      selectedCameraIdx = selectedCameraIdx;
    });
    Timer(Duration(seconds: 2), () {
      disableFlipButton.value = false;
      disableFlipButton.notifyListeners();
    });
  }

  Future<String> enableVideo(BuildContext context) async {
    try {
      Uri apiUrl = Helper.getUri('video-enabled');
      var response = await Dio().post(
        apiUrl.toString(),
        options: Options(
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer ' + userRepo.currentUser.value.token,
          },
        ),
        queryParameters: {
          "video_id": videoId,
          "description": description,
          "privacy": privacy,
        },
      );
      if (response.statusCode == 200) {
        if (response.data['status'] == 'success') {
          setState(() {
            isUploading.value = true;
            isUploading.notifyListeners();
            showLoader = false;
          });
          Navigator.of(scaffoldKey.currentContext!).popAndPushNamed('/my-profile');
        } else {
          var msg = response.data['msg'];
          ScaffoldMessenger.of(scaffoldKey.currentContext!).showSnackBar(
            Helper.toast(msg, Colors.red),
          );
        }
      }
      setState(() {
        showLoader = false;
      });
    } catch (e) {
      var msg = e.toString();
      ScaffoldMessenger.of(scaffoldKey.currentContext!).showSnackBar(
        Helper.toast(msg, Colors.red),
      );
      setState(() {
        showLoader = false;
      });
    }
    return responsePath;
  }

  Future saveAudio(audio) async {
    DefaultCacheManager().getSingleFile(audio).then((value) {
      // setState(() {
      audioFile = value.path;
      // });
      print("audioFile $audioFile");
      assetsAudioPlayer.open(
        Audio.file(audioFile),
        autoStart: false,
        volume: 0.05,
      );
    });
  }

  Future<String> downloadFile(uri, fileName) async {
    bool downloading;
    bool isDownloaded;
    String progress = "";
    setState(() {
      downloading = true;
    });
    String savePath = await getFilePath(fileName);
    Dio dio = Dio();
    dio.download(
      uri.trim(),
      savePath,
      onReceiveProgress: (rcv, total) {
        progress = ((rcv / total) * 100).toStringAsFixed(0);
        if (progress == '100') {
          isDownloaded = true;
        } else if (double.parse(progress) < 100) {}
      },
      deleteOnError: true,
    ).then((_) {
      if (progress == '100') {
        isDownloaded = true;
      }
      downloading = false;
    });
    return savePath;
  }

  willPopScope(context) async {
    if (EasyLoading.isShow) {
      EasyLoading.dismiss();
      return Future.value(false);
    } else if (isVideoRecorded == true) {
      return exitConfirm(context);
    } else {
      try {
        if (videoEditorController!.initialized) {
          videoEditorController!.dispose();
        }
        controller!.dispose();
      } catch (e) {
        print("Error $e");
      }
      assetsAudioPlayer.dispose();
      videoRepo.outputVideoAfter1StepPath = new ValueNotifier("");
      videoRepo.outputVideoPath = new ValueNotifier("");
      videoRepo.watermarkUri = new ValueNotifier("");
      videoRepo.thumbImageUri = new ValueNotifier("");
      videoRepo.isOnRecordingPage.value = false;
      videoRepo.isOnRecordingPage.notifyListeners();
      videoRepo.homeCon.value.showFollowingPage.value = false;
      videoRepo.homeCon.value.showFollowingPage.notifyListeners();
      videoRepo.homeCon.value.getVideos();

      if (animationController != null) animationController!.dispose();

      if (videoController != null) videoController!.dispose();
      if (controller != null) if (controller != null) controller!.dispose();

      try {
        if (videoEditorController != null) {
          videoEditorController!.dispose();
          videoEditorController!.video.dispose();
        }
      } catch (e) {
        print("videoEditorController disposing exception $e");
      }
      try {
        previewVideoController!.dispose();
      } catch (e) {
        print("previewVideoController disposing exception $e");
      }
      super.dispose();
      return Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void exitConfirm(context) {
    AwesomeDialog(
      dialogBackgroundColor: settingRepo.setting.value.buttonColor,
      context: GlobalVariable.navState.currentContext!,
      animType: AnimType.SCALE,
      dialogType: DialogType.question,
      body: Column(
        children: <Widget>[
          "Do you really want to discard "
                  "the video?"
              .text
              .color(settingRepo.setting.value.textColor!)
              .size(16)
              .center
              .make()
              .centered()
              .pSymmetric(v: 10),
          SizedBox(
            height: 10,
          ),
          InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop("Discard");
            },
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(new Radius.circular(32.0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    GestureDetector(
                        onTap: () async {
                          try {
                            if (videoEditorController!.initialized) {
                              videoEditorController!.dispose();
                            }
                            controller!.dispose();
                          } catch (e) {
                            print("Error $e");
                          }
                          videoRepo.outputVideoAfter1StepPath = new ValueNotifier("");
                          videoRepo.outputVideoPath = new ValueNotifier("");
                          videoRepo.watermarkUri = new ValueNotifier("");
                          videoRepo.thumbImageUri = new ValueNotifier("");
                          videoRepo.isOnRecordingPage.value = false;
                          videoRepo.isOnRecordingPage.notifyListeners();
                          soundRepo.currentSound = new ValueNotifier(SoundData(soundId: 0, title: ""));
                          soundRepo.currentSound.notifyListeners();
                          videoRepo.homeCon.value.showFollowingPage.value = false;
                          videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                          if (animationController != null) animationController!.dispose();
                          assetsAudioPlayer.dispose();
                          if (controller != null) controller!.dispose();
                          try {
                            if (videoEditorController != null) {
                              videoEditorController!.dispose();
                              videoEditorController!.video.dispose();
                            }
                          } catch (e) {
                            print("videoEditorController disposing exception $e");
                          }
                          try {
                            previewVideoController!.dispose();
                          } catch (e) {
                            print("previewVideoController disposing exception $e");
                          }
                          videoRepo.homeCon.value.getVideos();
                          Navigator.pop(context);
                          Navigator.of(context).pushReplacementNamed('/home');
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
                              style: TextStyle(color: settingRepo.setting.value.textColor, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'RockWellStd'),
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
                              color: settingRepo.setting.value.textColor,
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
          SizedBox(
            height: 15,
          ),
        ],
      ),
    )..show();
  }

  Future<String> getFilePath(uniqueFileName) async {
    String path = '';
    Directory dir;
    if (!Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = (await getExternalStorageDirectory())!;
    }
    path = '${dir.path}/$uniqueFileName';

    return path;
  }

  Future uploadGalleryVideo() async {
    File file = File("");
    final picker = ImagePicker();
    Directory appDirectory;
    if (!Platform.isAndroid) {
      appDirectory = await getApplicationDocumentsDirectory();
      print(appDirectory);
    } else {
      appDirectory = (await getExternalStorageDirectory())!;
    }
    final String outputDirectory = '${appDirectory.path}/outputVideos';
    await Directory(outputDirectory).create(recursive: true);
    final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
    final String thumbImg = '$outputDirectory/${currentTime}.jpg';
    final String outputVideo = '$outputDirectory/${currentTime}.mp4';
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      file = File(pickedFile.path);
    } else {
      print('No image selected. ${file.path}');
    }
    if (file.path != "") {
      String ffprobeCommand = "-v error -select_streams a -show_entries stream=index -of csv=p=0  ${file.path}";
      String ffprobeOutputStream = "123";
      await FFprobeKit.execute(ffprobeCommand).then((session) async {
        var outputStreams = await session.getOutput();
        print("ffprobe output : a-$outputStreams-a ${outputStreams.runtimeType} ${outputStreams!.length} ");
        ffprobeOutputStream = outputStreams;
      }).whenComplete(() async {
        if (ffprobeOutputStream == "") {
          AwesomeDialog(
            dialogBackgroundColor: settingRepo.setting.value.buttonColor,
            context: GlobalVariable.navState.currentContext!,
            animType: AnimType.SCALE,
            dialogType: DialogType.WARNING,
            body: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        "Unsupported Video Stream",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        "Video must contain at least one audio stream. You must turn on Microphone or select an music file form the music listing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      videoRepo.homeCon.value.showFollowingPage.value = false;
                      videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                      videoRepo.homeCon.value.getVideos();
                      Navigator.of(scaffoldKey.currentContext!).pushReplacementNamed('/home');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: settingRepo.setting.value.accentColor,
                      ),
                      child: "Close".text.size(18).center.color(settingRepo.setting.value.textColor!).make().centered().pSymmetric(h: 10, v: 10),
                    ),
                  )
                ],
              ),
            ),
          )..show();
          return;
        } else {
          VideoPlayerController? _outputVideoController;
          try {
            _outputVideoController = VideoPlayerController.file(File(file.path));
            await _outputVideoController.initialize();
          } on CameraException catch (e) {
            EasyLoading.dismiss();
            showCameraException("There's some error loading video" as CameraException, scaffoldKey.currentContext!);
            return;
          }
          print("_outputVideoController.value.duration.inSeconds");
          print(_outputVideoController.value.duration.inSeconds);
          print(videoRepo.selectedVideoLength.value.toInt());
          /*if (_outputVideoController.value.duration.inSeconds <= videoRepo.selectedVideoLength.value.toInt()) {
            String comm = '-i ${file.path} -vf "scale=' + "'min(560,iw)'" + ':-2" -c:v libx264  -preset ultrafast -crf 23  $outputVideo';
            FFmpegKit.executeAsync(
              // '-y -i $videoPath $audioFile  -filter_complex "$mergeAudioArgs[0:v]scale=560:-2$watermarkArgs" -c:v libx264 $mergeAudioArgs2 $audioFileArgs -preset ultrafast -crf 23  $outputVideo',
              '-y $comm',
              (session) async {
                EasyLoading.dismiss(animation: true);
                print("FFmpegKit.executeAsync in Command");

                // Unique session id created for this execution
                final sessionId = session.getSessionId();
                print("FFmpegKit.executeAsync sessionId $sessionId");
                // Command arguments as a single string
                final command = session.getCommand();
                print("ffmpeg command $command");

                // The list of logs generated for this execution
                final logs = await session.getLogs();
                print("ffmpegLogs $logs");
                logs.forEach((element) {
                  print("::");
                  print(element.getMessage());
                });

                // The list of statistics generated for this execution (only available on FFmpegSession)
                final statistics = await (session as FFmpegSession).getStatistics();

                videoPath = outputVideo;
                _outputVideoController!.dispose();
                videoRepo.outputVideoPath.value = outputVideo;
                videoRepo.outputVideoPath.notifyListeners();
                Navigator.of(scaffoldKey.currentContext!).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) {
                      return VideoEditor(file: file);
                    },
                  ),
                );
              },
              null,
              (statics) {
                // First statistics is always wrong so if first one skip it
                if (_firstStat) {
                  _firstStat = false;
                } else {
                  String stats = "Encoding Video ${((statics.getTime() / _outputVideoController!.value.duration.inMilliseconds) * 100).ceil()}%";
                  EasyLoading.showProgress(
                    ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                    status: stats,
                    maskType: EasyLoadingMaskType.black,
                  );
                }
              },
            );
          } else {*/
          _outputVideoController.dispose();
          videoRepo.outputVideoPath.value = file.path;
          videoRepo.outputVideoPath.notifyListeners();
          Navigator.of(scaffoldKey.currentContext!).pushReplacement(
            MaterialPageRoute(
              builder: (context) {
                return VideoEditor(file: file);
              },
            ),
          );
          // }
        }
      });
    }
  }

  Future<bool> uploadVideo(videoFilePath, thumbFilePath) async {
    isUploading.value = true;
    isUploading.notifyListeners();
    Uri url = Helper.getUri('upload-video');
    String videoFileName = videoFilePath.split('/').last;
    String thumbFileName = thumbFilePath.split('/').last;
    FormData formData = FormData.fromMap({
      "video": await MultipartFile.fromFile(videoFilePath, filename: videoFileName),
      "thumbnail_file": await MultipartFile.fromFile(thumbFilePath, filename: thumbFileName),
      "privacy": privacy,
    });
    var response = await Dio().post(
      url.toString(),
      options: Options(
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ' + userRepo.currentUser.value.token,
        },
      ),
      data: formData,
      queryParameters: {
        "description": description,
        "sound_id": soundRepo.mic.value
            ? 0
            : soundRepo.currentSound.value.soundId > 0
                ? soundRepo.currentSound.value.soundId
                : audioId
      },
      onSendProgress: (int sent, int total) {
        uploadProgress.value = sent / total;
        uploadProgress.notifyListeners();
        if (uploadProgress.value >= 100) {
          isUploading.value = false;
          isUploading.notifyListeners();
          videoRepo.thumbImageUri.value = "";
          videoRepo.thumbImageUri.notifyListeners();
          videoRepo.outputVideoPath.value = "";
          videoRepo.outputVideoPath.notifyListeners();
        }
      },
    );
    soundRepo.currentSound = new ValueNotifier(SoundData(soundId: 0, title: ""));
    soundRepo.currentSound.notifyListeners();
    if (response.statusCode == 200) {
      if (response.data['status'] == 'success') {
        // setState(() {
        isUploading.value = true;
        isUploading.notifyListeners();
        showLoader = false;
        return true;
      } else {
        var msg = response.data['msg'];
        AwesomeDialog(
          dialogBackgroundColor: settingRepo.setting.value.buttonColor,
          context: GlobalVariable.navState.currentContext!,
          animType: AnimType.SCALE,
          dialogType: DialogType.WARNING,
          body: Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      "Video Flagged",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    videoRepo.homeCon.value.showFollowingPage.value = false;
                    videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                    videoRepo.homeCon.value.getVideos();
                    Navigator.of(scaffoldKey.currentContext!).pushReplacementNamed('/home');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: settingRepo.setting.value.accentColor,
                    ),
                    child: "Close".text.size(18).center.color(settingRepo.setting.value.textColor!).make().centered().pSymmetric(h: 10, v: 10),
                  ),
                )
              ],
            ),
          ),
        )..show();
        return false;
      }
    } else {
      return false;
    }
  }

  convertToBase(file) async {
    List<int> vidBytes = await File(file).readAsBytes();
    String base64Video = base64Encode(vidBytes);
    return base64Video;
  }

  void startWaitTimer() {
    /*if (waitTimer != null) {
      waitTimer.cancel();
    }*/
    waitTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (startTimerTiming.value > 0) {
        startTimerTiming.value--;
        startTimerTiming.notifyListeners();
      } else {
        waitTimer.cancel();
      }
    });
  }

  Future<void> onRecordButtonPressed(BuildContext context) async {
    isVideoRecorded = true;
    videoRecorded = true;
    isRecordingPaused = false;
    if (startTimerTiming.value > 0) {
      Duration waitSeconds = Duration(seconds: startTimerTiming.value);
      startWaitTimer();
      await Future.delayed(waitSeconds);
    }
    startVideoRecording(context).whenComplete(() {
      showProgressBar = true;
      startTimer(context);
      if (soundRepo.mic.value) {
        assetsAudioPlayer.setVolume(0.2);
      } else {
        assetsAudioPlayer.setVolume(0.6);
      }
      assetsAudioPlayer.play();
      cameraPreview.value = true;
      cameraPreview.notifyListeners();
    });
  }

  void onStopButtonPressed() {
    timer.cancel();
    if (soundRepo.currentSound.value.soundId > 0) {
      assetsAudioPlayer.pause();
    }

    videoRecorded = false;
    isProcessing = true;
    EasyLoading.show(
      status: "loading..",
      maskType: EasyLoadingMaskType.black,
    );
    stopVideoRecording().then((String outputVideo) async {});
  }

  void onPauseButtonPressed(BuildContext context) {
    if (soundRepo.currentSound.value.soundId > 0) {
      assetsAudioPlayer.pause();
    }
    // setState(() {
    isRecordingPaused = true;
    pauseTime = DateTime.now();
    // });
    pauseVideoRecording(context).then((_) {
      // setState(() {
      videoRecorded = false;
      timer.cancel();
      // });
    });
  }

  void onResumeButtonPressed(BuildContext context) {
    assetsAudioPlayer.play();
    playTime = DateTime.now();
    isRecordingPaused = false;
    try {
      endShift.value.add(Duration(milliseconds: playTime.difference(pauseTime).inMilliseconds));
      endShift.notifyListeners();
    } catch (e) {
      print("endShift.value error $e");
    }
    resumeVideoRecording(context).then((_) {
      videoRecorded = true;
      startTimer(context);
    });
  }

  Future<void> startVideoRecording(BuildContext context) async {
    if (!controller!.value.isInitialized) {
      return null;
    }
    if (controller!.value.isRecordingVideo) {
      return null;
    }
    Directory? appDirectory;
    if (!Platform.isAndroid) {
      appDirectory = await getApplicationDocumentsDirectory();
    } else {
      appDirectory = await getExternalStorageDirectory();
    }
    final String videoDirectory = '${appDirectory!.path}/Videos';
    await Directory(videoDirectory).create(recursive: true);
    final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = '$videoDirectory/$currentTime.mp4';

    try {
      await controller!.startVideoRecording();
      endShift.value =
          DateTime.now().add(Duration(milliseconds: videoRepo.selectedVideoLength.value.toInt() * 1000 + int.parse((videoRepo.selectedVideoLength.value.toInt() / 15).toStringAsFixed(0)) * 104));
      endShift.notifyListeners();
    } on CameraException catch (e) {
      showCameraException(e, context);
      return null;
    }
  }

  Future<void> pauseVideoRecording(BuildContext context) async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      showCameraException(e, context);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording(BuildContext context) async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      showCameraException(e, context);
      rethrow;
    }
  }

  Future<String> stopVideoRecording() async {
    assetsAudioPlayer.pause();
    if (!controller!.value.isRecordingVideo) {
      return "";
    }
    if (!videoRepo.isOnRecordingPage.value) {
      return "";
    }
    try {
      await controller!.stopVideoRecording().then((file) {
        videoPath = file.path;
        // Helper.downloadLocalFile(videoPath);
      });
    } on CameraException catch (e) {
      showCameraException(e, scaffoldKey.currentContext!);
      return "";
    }
    Directory appDirectory;
    if (!Platform.isAndroid) {
      appDirectory = await getApplicationDocumentsDirectory();
      print(appDirectory);
    } else {
      appDirectory = (await getExternalStorageDirectory())!;
    }
    VideoPlayerController? _outputVideoController;
    try {
      _outputVideoController = VideoPlayerController.file(File(videoPath));
      await _outputVideoController.initialize();
    } on CameraException catch (e) {
      EasyLoading.dismiss();
      showCameraException("There's some error loading video" as CameraException, scaffoldKey.currentContext!);
      return "";
    }
    final String outputDirectory = '${appDirectory.path}/outputVideos';
    await Directory(outputDirectory).create(recursive: true);
    final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputVideo = '$outputDirectory/$currentTime.mp4';
    final String thumbImg = '$outputDirectory/$currentTime.jpg';
    String responseVideo = "";
    String audioFileArgs = '';
    String audioFileArgs2 = '';
    String mergeAudioArgs = '';
    String mergeAudioArgs2 = '';
    String watermarkArgs = '';
    String presetString = '';
    if (watermark != '') {
      // watermark = " -i $watermark";
      // watermarkArgs = ",overlay=W-w-5:5";
    }
    if (soundRepo.mic.value && audioFile != '') {
      audioFile = "";
      presetString = '-preset ultrafast';
    }
    if (!soundRepo.mic.value && audioFile != '') {
      audioFile = " -i $audioFile";
      presetString = '-preset ultrafast -crf 28';
      mergeAudioArgs2 = "-map 0:v:0 -map 1:a:0";
      audioFileArgs = '-c:a aac -ac 2 -ar 22050 -shortest -b:a 64k';
    }
    try {
      print('ffmpeg -i $videoPath $watermark $audioFile  -filter_complex "$mergeAudioArgs[0:v]scale=560:-2$watermarkArgs" -c libx265  $mergeAudioArgs2 $audioFileArgs  $presetString $outputVideo');

      FFmpegKit.executeAsync(
          // '-y -i $videoPath $audioFile  -filter_complex "$mergeAudioArgs[0:v]scale=560:-2$watermarkArgs" -c:v libx264 $mergeAudioArgs2 $audioFileArgs -preset ultrafast -crf 23  $outputVideo',
          '-y -i $videoPath $audioFile  -filter_complex "$mergeAudioArgs[0:v]scale=560:-2$watermarkArgs" -c:v libx264 $mergeAudioArgs2 $audioFileArgs -preset ultrafast  $outputVideo',
          (session) async {
            EasyLoading.dismiss(animation: true);
            print("FFmpegKit.executeAsync in Command");
            // Unique session id created for this execution
            final sessionId = session.getSessionId();
            print("FFmpegKit.executeAsync sessionId $sessionId");
            // Command arguments as a single string
            final command = session.getCommand();
            print("ffmpeg command $command");

            // The list of logs generated for this execution
            final logs = await session.getLogs();
            print("ffmpegLogs $logs");
            logs.forEach((element) {
              print("::");
              print(element.getMessage());
            });

            // The list of statistics generated for this execution (only available on FFmpegSession)
            final statistics = await (session as FFmpegSession).getStatistics();

            videoPath = outputVideo;
            String ffprobeCommand = "-v error -select_streams a -show_entries stream=index -of csv=p=0  $videoPath";
            String ffprobeOutputStream = "123";
            await FFprobeKit.execute(ffprobeCommand).then((session) async {
              var outputStreams = await session.getOutput();
              print("ffprobe output : a-$outputStreams-a ${outputStreams.runtimeType} ${outputStreams!.length} ");
              ffprobeOutputStream = outputStreams;
            });
            if (ffprobeOutputStream == "") {
              AwesomeDialog(
                dialogBackgroundColor: settingRepo.setting.value.buttonColor,
                context: GlobalVariable.navState.currentContext!,
                animType: AnimType.SCALE,
                dialogType: DialogType.WARNING,
                body: Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Text(
                            "Unsupported Video Stream",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Text(
                            "Video must contain at least one audio stream. You must turn on Microphone or select an music file form the music listing.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          videoRepo.homeCon.value.showFollowingPage.value = false;
                          videoRepo.homeCon.value.showFollowingPage.notifyListeners();
                          videoRepo.homeCon.value.getVideos();
                          Navigator.of(scaffoldKey.currentContext!).pushReplacementNamed('/home');
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: settingRepo.setting.value.accentColor,
                          ),
                          child: "Close".text.size(18).center.color(settingRepo.setting.value.textColor!).make().centered().pSymmetric(h: 10, v: 10),
                        ),
                      )
                    ],
                  ),
                ),
              )..show();
              return;
            }
            videoRepo.outputVideoPath.value = outputVideo;
            videoRepo.outputVideoPath.notifyListeners();

            try {
              _outputVideoController!.dispose();
              isProcessing = false;
              _firstStat = true;
              EasyLoading.dismiss(animation: true);
              scaffoldKey.currentContext!.to(
                VideoEditor(
                  file: File(
                    videoPath,
                  ),
                ),
              );
            } catch (e) {
              print("videoPath error : $e");
            }
          },
          null,
          (statics) {
            // First statistics is always wrong so if first one skip it
            if (_firstStat) {
              _firstStat = false;
            } else {
              String stats = "Processing Video ${((statics.getTime() / _outputVideoController!.value.duration.inMilliseconds) * 100).ceil()}%";
              EasyLoading.showProgress(
                ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                status: stats,
                maskType: EasyLoadingMaskType.black,
              );
            }
          });
    } catch (e) {
      print("Error redcordomgd");
      print(e.toString());
    }
    return outputVideo;
  }

  final fonts = [
    'Alegreya',
    'B612',
    'TitilliumWeb',
    'Varela',
    'Vollkorn',
    'Rakkas',
    'ConcertOne',
    'YatraOne',
    'OldStandardTT',
    'Neonderthaw',
    'DancingScript',
    'SedgwickAve',
    'IndieFlower',
    'Sacramento',
    'PressStart2P',
    'FrederickatheGreat',
    'ReenieBeanie',
    'BungeeShade',
    'UnifrakturMaguntia'
  ];

  startTimer(BuildContext context) {
    timer = Timer.periodic(new Duration(milliseconds: 100), (timer) {
      videoProgressPercent.value += 1 / (videoRepo.selectedVideoLength.value * 10);
      videoProgressPercent.notifyListeners();
      if (videoProgressPercent.value >= 1) {
        isProcessing = true;
        cameraPreview.value = true;
        cameraPreview.notifyListeners();
        videoProgressPercent.value = 1;
        videoProgressPercent.notifyListeners();
        timer.cancel();
        onStopButtonPressed();
      }
    });
  }

  void getTimeLimits() {
    settingRepo.setting.value.videoTimeLimits.forEach((element) {
      videoTimerLimit.value.add(double.parse(element));
    });
    videoTimerLimit.notifyListeners();
  }

  Future<void> processTextFilter(BuildContext context, String uri, {bool skip = false}) async {
    print("processTextFilter uri: $uri watermark: ${videoRepo.watermarkUri.value} outputVideoPath: ${videoRepo.outputVideoPath.value}");
    previewVideoController!.pause();
    EasyLoading.show(
      status: "loading..",
      maskType: EasyLoadingMaskType.black,
    );
    print("processTextFilter $uri ${videoRepo.watermarkUri.value} ${videoRepo.outputVideoPath.value}");
    String loadingMessage = "";
    if (skip) {
      loadingMessage = "Adding watermark...";
    } else {
      loadingMessage = "Adding text filter and watermark...";
    }
    final VideoPlayerController _outputVideoController = VideoPlayerController.file(File(videoRepo.outputVideoPath.value));
    _outputVideoController.initialize().then((value) async {
      Directory appDirectory;
      if (!Platform.isAndroid) {
        appDirectory = await getApplicationDocumentsDirectory();
        print(appDirectory);
      } else {
        appDirectory = (await getExternalStorageDirectory())!;
      }
      final String outputDirectory = '${appDirectory.path}/outputVideos';
      await Directory(outputDirectory).create(recursive: true);
      final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
      var watermarkArgs = "";
      var textFilterArgs = "";
      var textFilter = "";
      var mapVar = "";
      final String outputVideo = '$outputDirectory/$currentTime.mp4';
      final String outputVideoWithWatermark = '$outputDirectory/$currentTime-watermarked.mp4';
      final String thumbImg = '$outputDirectory/$currentTime.jpg';
      if (uri != "") {
        File image = new File(uri); // Or any other way to get a File instance.
        var decodedImage = await decodeImageFromList(image.readAsBytesSync());
        print(decodedImage.width);
        print(decodedImage.height);
        int width = (decodedImage.width / 2).ceil() * 2;
        int height = (decodedImage.height / 2).ceil() * 2;
        textFilterArgs = "scale='min(iw*$height/ih,$width):min($height,ih*$width/iw)',pad=$width:$height:($width-iw)/2:($height-ih)/2[sc];[sc][1]overlay[vo]";
        // textFilterArgs = "scale='min(iw*$height/ih,$width):min($height,ih*$width/iw)',pad='max(" + '"min(iw*$height/ih,$width)"' + ",$width)':'max(" + '"min($height,ih*$width/iw)"' + ",$height)':'max((ow-iw)/2,($width-iw)/2)':'max((oh-ih)/2,($height-ih)/2)'[sc];[sc][1]overlay[vo]";
        /*textFilterArgs = "scale='min(iw*" +
            '("ceil($height/2)"*2)' +
            '/ih,' +
            '("ceil($width/2)"*2)):min' +
            '("ceil($height/2)"*2,ih*' +
            '("ceil($width/2)"' +
            "*2))/iw',pad=" +
            '("ceil($width/2)"*2):' +
            '("ceil($height/2)"*2):(' +
            '("ceil($width/2)"*2)-iw)/2:(' +
            '("ceil($height/2)"' +
            "*2)-ih)/2[sc];[sc][1]overlay[vo]";*/
        textFilter = "-i $uri";
        mapVar = "[vo]";
        if (videoRepo.watermarkUri.value != '') {
          watermarkArgs = ";[2][vo]scale2ref=w='iw*25/100':h='ow/mdar'[wm][vid];[vid][wm]overlay=W-w-25:25[final]";
          mapVar = "[final]";
          watermark = " -i ${videoRepo.watermarkUri.value}";
        }
      }
      EasyLoading.dismiss();
      try {
        if (skip) {
          print("Skipped Text Filter");
          if (videoRepo.outputVideoPath.value != "") {
            if (videoRepo.watermarkUri.value != '') {
              print("Entered Watewrmark Filter");
              watermark = " -i ${videoRepo.watermarkUri.value}";
              watermarkArgs = "[1][0]scale2ref=w='iw*25/100':h='ow/mdar'[wm][vid];[vid][wm]overlay=W-w-25:25";
              // watermarkArgs = "overlay=W-w-5:5";
              FFmpegKit.executeAsync(
                  '-y -i ${videoRepo.outputVideoPath.value} $watermark -filter_complex "$watermarkArgs" -preset ultrafast -crf 23  $outputVideo',
                  (session) async {
                    print("FFmpegKit.executeAsync in Command");
                    // Unique session id created for this execution
                    final sessionId = session.getSessionId();
                    print("FFmpegKit.executeAsync sessionId $sessionId");
                    // Command arguments as a single string
                    final command = session.getCommand();
                    print("ffmpeg command $command");
                    final logs = await session.getLogs();
                    print("ffmpegLogs $logs");
                    logs.forEach((element) {
                      print("::");
                      print(element.getMessage());
                    });
                    try {
                      videoPath = outputVideo;
                      videoRepo.outputVideoPath.value = videoPath;
                      videoRepo.outputVideoPath.notifyListeners();
                      print("fail 1 1220 ");
                      print("-i $videoPath -ss 00:00:00.000 -vframes 1 -preset ultrafast $thumbImg");
                      FFmpegKit.executeAsync(
                          "-i $videoPath -ss 00:00:00.000 -vframes 1 -preset ultrafast $thumbImg",
                          (session) async {
                            print("FFmpegKit.executeAsync in Command");
                            // Unique session id created for this execution
                            final sessionId = session.getSessionId();
                            print("FFmpegKit.executeAsync sessionId $sessionId");
                            // Command arguments as a single string
                            final command = session.getCommand();
                            print("ffmpeg command $command");
                            // The list of logs generated for this execution
                            final logs = await session.getLogs();
                            print("ffmpegLogs $logs");
                            logs.forEach((element) {
                              print("::");
                              print(element.getMessage());
                            });
                            thumbPath = thumbImg;
                            videoRepo.thumbImageUri.value = thumbImg;
                            setState(() {
                              isProcessing = false;
                            });
                            openPreviewWindow(context);
                            EasyLoading.dismiss();
                          },
                          null,
                          (statics) {
                            // First statistics is always wrong so if first one skip it
                            if (_firstStat) {
                              _firstStat = false;
                            } else {
                              String stats = "Generating cover image ${((statics.getTime() / _outputVideoController.value.duration.inMilliseconds) * 100).ceil()}%";
                              EasyLoading.showProgress(
                                ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                                status: stats,
                                maskType: EasyLoadingMaskType.black,
                              );
                            }
                          });
                    } catch (e) {
                      EasyLoading.dismiss();
                      print("videoPath error : $e");
                    }
                  },
                  null,
                  (statics) {
                    // First statistics is always wrong so if first one skip it
                    if (_firstStat) {
                      _firstStat = false;
                    } else {
                      String stats = "$loadingMessage ${((statics.getTime() / _outputVideoController.value.duration.inMilliseconds) * 100).ceil()}%";
                      EasyLoading.showProgress(
                        ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                        status: stats,
                        maskType: EasyLoadingMaskType.black,
                      );
                    }
                  });
            } else {
              print("fail 2 1284");
              print("-i ${videoRepo.outputVideoPath.value} -ss 00:00:00.000 -vframes 1 -preset ultrafast $thumbImg");
              FFmpegKit.executeAsync(
                  "-i ${videoRepo.outputVideoPath.value} -ss 00:00:00.000 -vframes 1 -preset ultrafast $thumbImg",
                  (session) async {
                    print("FFmpegKit.executeAsync in Command");
                    // Unique session id created for this execution
                    final sessionId = session.getSessionId();
                    print("FFmpegKit.executeAsync sessionId $sessionId");
                    // Command arguments as a single string
                    final command = session.getCommand();
                    print("ffmpeg command $command");

                    // The list of logs generated for this execution
                    final logs = await session.getLogs();
                    print("ffmpegLogs $logs");
                    logs.forEach((element) {
                      print("::");
                      print(element.getMessage());
                    });
                    thumbPath = thumbImg;
                    videoRepo.thumbImageUri.value = thumbImg;
                    // setState(() {
                    isProcessing = false;
                    // });
                    if (videoRepo.outputVideoPath.value != "") {
                      openPreviewWindow(context);
                    }
                  },
                  null,
                  (statics) {
                    // First statistics is always wrong so if first one skip it
                    if (_firstStat) {
                      _firstStat = false;
                    } else {
                      String stats = "Generating cover image ${((statics.getTime() / _outputVideoController.value.duration.inMilliseconds) * 100).ceil()}%";
                      EasyLoading.showProgress(
                        ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                        status: stats,
                        maskType: EasyLoadingMaskType.black,
                      );
                    }
                  });
            }

            return null;
          }
        } else {
          print("Text Filter done");
          FFmpegKit.executeAsync(
              // '-y -i ${videoRepo.outputVideoPath.value} $textFilter $watermark -filter_complex "$textFilterArgs$watermarkArgs" -map "[final]" -map 0:a -preset ultrafast -crf 23  $outputVideo',
              '-y -i ${videoRepo.outputVideoPath.value} $textFilter $watermark -filter_complex "$textFilterArgs$watermarkArgs" -map "$mapVar" -map 0:a -preset ultrafast -crf 23  $outputVideo',
              (session) async {
                print("FFmpegKit.executeAsync in Command");
                // Unique session id created for this execution
                final sessionId = session.getSessionId();
                print("FFmpegKit.executeAsync sessionId $sessionId");
                // Command arguments as a single string
                final command = session.getCommand();
                print("ffmpeg command $command");

                // The list of logs generated for this execution
                final logs = await session.getLogs();
                print("ffmpegLogs $logs");
                logs.forEach((element) {
                  print("::");
                  print(element.getMessage());
                });

                // The list of statistics generated for this execution (only available on FFmpegSession)
                final statistics = await (session as FFmpegSession).getStatistics();

                // setState(() {
                videoPath = outputVideo;
                videoRepo.outputVideoPath.value = outputVideo;
                videoPath = outputVideo;
                _outputVideoController.dispose();
                print("fail 3 1363");
                print("-i $videoPath -ss 00:00:00.000 -vframes 1 -preset ultrafast $thumbImg");
                FFmpegKit.executeAsync(
                    "-i $videoPath -ss 00:00:00.000 -vframes 1 -preset ultrafast  $thumbImg",
                    (session) async {
                      print("FFmpegKit.executeAsync in Command");
                      // Unique session id created for this execution
                      final sessionId = session.getSessionId();
                      print("FFmpegKit.executeAsync sessionId $sessionId");
                      // Command arguments as a single string
                      final command = session.getCommand();
                      print("ffmpeg command $command");

                      // The list of logs generated for this execution
                      final logs = await session.getLogs();
                      print("ffmpegLogs $logs");
                      logs.forEach((element) {
                        print("::");
                        print(element.getMessage());
                      });
                      thumbPath = thumbImg;
                      videoRepo.thumbImageUri.value = thumbImg;
                      setState(() {
                        isProcessing = false;
                      });
                      openPreviewWindow(context);
                    },
                    null,
                    (statics) {
                      // First statistics is always wrong so if first one skip it
                      if (_firstStat) {
                        _firstStat = false;
                      } else {
                        String stats = "Generating cover image ${((statics.getTime() / _outputVideoController.value.duration.inMilliseconds) * 100).ceil()}%";
                        EasyLoading.showProgress(
                          ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                          status: stats,
                          maskType: EasyLoadingMaskType.black,
                        );
                      }
                    });
                // }

                return null;
                // });
              },
              null,
              (statics) {
                // First statistics is always wrong so if first one skip it
                if (_firstStat) {
                  _firstStat = false;
                } else {
                  String stats = "Adding Text Filter ${((statics.getTime() / _outputVideoController.value.duration.inMilliseconds) * 100).ceil()}%";
                  EasyLoading.showProgress(
                    ((statics.getTime() / _outputVideoController.value.duration.inMilliseconds)),
                    status: stats,
                    maskType: EasyLoadingMaskType.black,
                  );
                }
              });
        }
      } catch (e) {
        print("error Text Filter exception $e");
        EasyLoading.dismiss();
      }
    });
  }

  void openPreviewWindow(BuildContext context) async {
    final VideoPlayerController _videoController = VideoPlayerController.file(File(videoRepo.outputVideoPath.value));
    _videoController.initialize().then(
      (value) async {
        setState(() {});
        _videoController.play();
        _videoController.setLooping(true);
        // Navigator.of(context).push(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) {
              final VideoPlayerController? localVideoController = _videoController;
              return WillPopScope(
                onWillPop: () async => false,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: localVideoController == null
                      ? Container()
                      : InkWell(
                          onTap: () {
                            print("asdasdasdasdasdas");
                            // setState(() {
                            if (localVideoController.value.isPlaying) {
                              localVideoController.pause();
                            } else {
                              localVideoController.play();
                            }
                            // });
                          },
                          child: Stack(
                            children: <Widget>[
                              SizedBox.expand(
                                child: (localVideoController == null)
                                    ? Container()
                                    : Container(
                                        color: Colors.black,
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.fitWidth,
                                            child: SizedBox(
                                              width: localVideoController.value.size.width,
                                              height: localVideoController.value.size.height,
                                              child: Center(
                                                child: Container(
                                                  child: Center(
                                                    child: AspectRatio(
                                                      aspectRatio: localVideoController.value.size != null ? localVideoController.value.aspectRatio : 1.0,
                                                      child: VideoPlayer(
                                                        localVideoController,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: localVideoController.value.isPlaying ? Colors.transparent : settingRepo.setting.value.dashboardIconColor,
                                    size: 80,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 50,
                                right: 20,
                                child: RawMaterialButton(
                                  onPressed: () {
                                    _videoController.dispose();

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoSubmit(
                                          thumbPath: videoRepo.thumbImageUri.value,
                                          videoPath: videoRepo.outputVideoPath.value,
                                          gifPath: "",
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
                                  onPressed: () async {
                                    videoRepo.outputVideoPath.value = videoRepo.outputVideoAfter1StepPath.value;
                                    videoRepo.outputVideoPath.notifyListeners();

                                    previewVideoController!.pause();
                                    var ret = await willPopScope(context);
                                    if (ret == Future.value(true)) {
                                      _videoController.dispose();
                                    }
                                  },
                                  /*onPressed: () {
                                    videoRepo.outputVideoPath.value = videoRepo.outputVideoAfter1StepPath.value;
                                    videoRepo.outputVideoPath.notifyListeners();
                                    _videoController.dispose();
                                    previewVideoController!.pause();
                                    Navigator.pop(context);
                                  },*/
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
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
        );
        EasyLoading.dismiss(animation: true);
        _firstStat = true;
        // _videoController.dispose();
      },
    );
  }

  void nextStep(BuildContext context) async {
    bool _firstStat = true;
    //NOTE: To use [-crf 17] and [VideoExportPreset] you need ["min-gpl-lts"] package
    await videoEditorController!.exportVideo(
      preset: VideoExportPreset.ultrafast,
      onProgress: (statics) {
        // First statistics is always wrong so if first one skip it
        if (_firstStat) {
          _firstStat = false;
        } else {
          int totalMillis = 0;
          if (videoEditorController!.video.value.duration.inMilliseconds <= videoRepo.selectedVideoLength.value * 1000) {
            totalMillis = videoEditorController!.video.value.duration.inMilliseconds;
          } else {
            totalMillis = (videoRepo.selectedVideoLength.value * 1000).toInt();
          }
          String stats = "Exporting video ${((statics.getTime() / totalMillis) * 100).ceil()}%";
          EasyLoading.showProgress(
            ((statics.getTime() / totalMillis)),
            status: stats,
            maskType: EasyLoadingMaskType.black,
          );
        }
      },
      onCompleted: (file) {
        EasyLoading.dismiss(animation: true);
        // _isExporting.value = false;
        // if (!mounted) return;
        if (file != null) {
          previewVideoController = VideoPlayerController.file(file);
          previewVideoController!.initialize().then((value) async {
            setState(() {});
            previewVideoController!.play();
            previewVideoController!.setLooping(true);
            showTextFilter.value = true;
            showTextFilter.notifyListeners();
            videoRepo.outputVideoAfter1StepPath.value = file.path;
            videoRepo.outputVideoAfter1StepPath.notifyListeners();
            videoRepo.outputVideoPath.value = file.path;
            videoRepo.outputVideoPath.notifyListeners();
            videoEditorController!.video.pause();
            openStoriesEditor(context);
          });
        }
        // setState(() => _exported = true);
        // Misc.delayed(2000, () => setState(() => _exported = false));
      },
    );
  }

  void openStoriesEditor(context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: Duration(
        milliseconds: 400,
      ),
      pageBuilder: (_, __, ___) {
        // your widget implementation
        return WillPopScope(
          onWillPop: () async => false,
          child: Container(
            // color: Colors.black.withOpacity(0.4),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                // top: false,
                child: StoriesEditor(
                  giphyKey: '[HERE YOUR API KEY]',
                  onDone: (uri) {
                    processTextFilter(context, uri);
                  },
                  fontFamilyList: fonts,
                  editorBackgroundColor: Colors.transparent,
                  middleBottomWidget: Container(),
                  onClose: () {
                    if (previewVideoController != null) previewVideoController!.dispose();
                    print("onClose Called");
                    showTextFilter.value = false;
                    showTextFilter.notifyListeners();
                    Navigator.pop(context);
                  },
                  onSkip: () {
                    processTextFilter(context, "", skip: true);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  trimVideoToMaxLength(String dataSource) async {
    Directory appDirectory;
    if (!Platform.isAndroid) {
      appDirectory = await getApplicationDocumentsDirectory();
      print(appDirectory);
    } else {
      appDirectory = (await getExternalStorageDirectory())!;
    }
    final String outputDirectory = '${appDirectory.path}/outputVideos';
    await Directory(outputDirectory).create(recursive: true);
    final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
    final String thumbImg = '$outputDirectory/${currentTime}.jpg';
    final String outputVideo = '$outputDirectory/${currentTime}.mp4';
    File file = File(dataSource);
    String finalDuration = Helper.getDurationString(Duration(seconds: videoRepo.selectedVideoLength.value.toInt()));
    String comm = '-i ${file.path} -ss 00:00:00 -to $finalDuration -vf "scale=' + "'min(560,iw)'" + ':-2" -c:v libx264  -preset ultrafast -crf 23  $outputVideo';
    FFmpegKit.executeAsync(
      // '-y -i $videoPath $audioFile  -filter_complex "$mergeAudioArgs[0:v]scale=560:-2$watermarkArgs" -c:v libx264 $mergeAudioArgs2 $audioFileArgs -preset ultrafast -crf 23  $outputVideo',
      '-y $comm',
      (session) async {
        EasyLoading.dismiss(animation: true);
        print("FFmpegKit.executeAsync in Command");

        // Unique session id created for this execution
        final sessionId = session.getSessionId();
        print("FFmpegKit.executeAsync sessionId $sessionId");
        // Command arguments as a single string
        final command = session.getCommand();
        print("ffmpeg command $command");

        // The list of logs generated for this execution
        final logs = await session.getLogs();
        print("ffmpegLogs $logs");
        logs.forEach((element) {
          print("::");
          print(element.getMessage());
        });

        // The list of statistics generated for this execution (only available on FFmpegSession)
        final statistics = await (session as FFmpegSession).getStatistics();

        videoPath = outputVideo;
        videoRepo.outputVideoPath.value = outputVideo;
        videoRepo.outputVideoPath.notifyListeners();
      },
      null,
      (statics) {
        // First statistics is always wrong so if first one skip it
        if (_firstStat) {
          _firstStat = false;
        } else {
          String stats = "Trimming Video ${((statics.getTime() / videoRepo.selectedVideoLength.value * 1000) * 100).ceil()}%";
          EasyLoading.showProgress(
            ((statics.getTime() / videoRepo.selectedVideoLength.value * 1000)),
            status: stats,
            maskType: EasyLoadingMaskType.black,
          );
        }
      },
    );
  }
}
