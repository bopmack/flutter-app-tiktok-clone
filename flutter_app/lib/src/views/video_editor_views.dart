import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:helpers/helpers.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import "package:velocity_x/velocity_x.dart";
// import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';

import '../controllers/video_recorder_controller.dart';
import '../repositories/settings_repository.dart' as settingRepo;
import '../repositories/video_repository.dart' as videoRepo;
import '../widgets/video_editor/video_editor.dart';

//-------------------//
//VIDEO EDITOR SCREEN//
//-------------------//
class VideoEditor extends StatefulWidget {
  VideoEditor({Key? key, required this.file}) : super(key: key);

  final File file;

  @override
  _VideoEditorState createState() => _VideoEditorState();
}

class _VideoEditorState extends StateMVC<VideoEditor> {
  VideoRecorderController _con = VideoRecorderController();
  _VideoEditorState() : super(VideoRecorderController()) {
    _con = VideoRecorderController();
  }
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);

  @override
  void initState() {
    _con.isVideoRecorded = true;
    _con.videoEditorController = VideoEditorController.file(widget.file, maxDuration: Duration(seconds: videoRepo.selectedVideoLength.value.toInt()))..initialize().then((_) => setState(() {}));
    _con.videoEditorController!.addListener(() {
      if (_con.videoEditorController!.minTrim > 0.0 ||
          _con.videoEditorController!.maxTrim < 0.99 ||
          _con.videoEditorController!.minCrop != Offset.zero ||
          _con.videoEditorController!.maxCrop != Offset(1.0, 1.0) ||
          _con.videoEditorController!.rotation > 0) {
        _con.showEditorDone.value = true;
        _con.showEditorDone.notifyListeners();
      } else {
        _con.showEditorDone.value = false;
        _con.showEditorDone.notifyListeners();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _con.videoEditorController!.dispose();
    _con.videoEditorController!.video.dispose();
    if (_con.previewVideoController != null) _con.previewVideoController!.dispose();
    super.dispose();
  }

  void openCropScreen() => context.to(CropScreen(controller: _con.videoEditorController!));

  void exportVideo() async {
    _isExporting.value = true;
    bool _firstStat = true;
    //NOTE: To use [-crf 17] and [VideoExportPreset] you need ["min-gpl-lts"] package
    await _con.videoEditorController!.exportVideo(
      // preset: VideoExportPreset.medium,
      // customInstruction: "-crf 17",

      onProgress: (statics) {
        // First statistics is always wrong so if first one skip it
        if (_firstStat) {
          _firstStat = false;
        } else {
          // _exportingProgress.value = statics.getTime() / _con.videoEditorController!.video.value.duration.inMilliseconds;
          _exportingProgress.value = statics.getTime() / videoRepo.selectedVideoLength.value * 1000;
        }
      },
      onCompleted: (file) {
        _isExporting.value = false;
        if (!mounted) return;
        if (file != null) {
          final VideoPlayerController _videoController = VideoPlayerController.file(file);
          _videoController.initialize().then((value) async {
            setState(() {});
            _videoController.play();
            _videoController.setLooping(true);
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.black54,
              builder: (_) => AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            );
            await _videoController.pause();
            _videoController.dispose();
          });
          _con.exportText = "Video success export!";
          setState(() {
            _con.videoPath = file.path;
            _con.watermark = _con.watermark;
          });
        } else {
          _con.exportText = "Error on export video :(";
        }
      },
    );
  }

  /*void exportCover() async {
    setState(() => _exported = false);
    await _con.videoEditorController.extractCover(
      onCompleted: (cover) {
        if (!mounted) return;

        if (cover != null) {
          _exportText = "Cover exported! ${cover.path}";
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.black54,
            builder: (BuildContext context) => Image.memory(cover.readAsBytesSync()),
          );
        } else
          _exportText = "Error on cover exportation :(";

        setState(() => _exported = true);
        Misc.delayed(2000, () => setState(() => _exported = false));
      },
    );
  }*/

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _con.willPopScope(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: settingRepo.setting.value.bgColor,
          automaticallyImplyLeading: false,
          elevation: 0,
          title: SizedBox(
            height: 10,
          ),
        ),
        extendBody: false,
        body: _con.videoEditorController!.initialized
            ? Stack(
                children: [
                  ValueListenableBuilder(
                    valueListenable: _con.showTextFilter,
                    builder: (_, bool showFilterWindow, __) => Column(
                      children: [
                        !showFilterWindow ? _topNavBar(context) : Container(),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    !showFilterWindow
                                        ? CropGridViewer(
                                            controller: _con.videoEditorController!,
                                            showGrid: false,
                                          )
                                        : SafeArea(
                                            minimum: EdgeInsets.symmetric(vertical: 10),
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: SizedBox(
                                                  width: _con.previewVideoController!.value.size.width,
                                                  height: _con.previewVideoController!.value.size.height,
                                                  child: Center(
                                                    child: AspectRatio(
                                                      aspectRatio: _con.previewVideoController!.value.size != null ? _con.previewVideoController!.value.aspectRatio : 1.0,
                                                      child: VideoPlayer(
                                                        _con.previewVideoController!,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    !showFilterWindow
                                        ? AnimatedBuilder(
                                            animation: _con.videoEditorController!.video,
                                            builder: (_, __) => OpacityTransition(
                                              visible: !_con.videoEditorController!.isPlaying,
                                              child: GestureDetector(
                                                onTap: _con.videoEditorController!.video.play,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.play_arrow, color: Colors.black),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(),
                                  ],
                                ),
                              ),
                              !showFilterWindow
                                  ? Container(
                                      height: 135,
                                      margin: Margin.top(10),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: _trimSlider(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(),
                              // _customSnackBar(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _isExporting,
                    builder: (_, bool export, __) => OpacityTransition(
                      visible: export,
                      child: AlertDialog(
                        backgroundColor: Colors.white,
                        title: ValueListenableBuilder(
                          valueListenable: _exportingProgress,
                          builder: (_, double value, __) => TextDesigned(
                            "Exporting video ${(value * 100).ceil()}%",
                            color: settingRepo.setting.value.textColor,
                            bold: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _topNavBar(BuildContext context) {
    return SafeArea(
      child: Container(
        height: _con.height,
        child: Row(
          children: [
            Expanded(
              child:

                  /// close button
                  InkWell(
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      onTap: () async {
                        _con.willPopScope(context);
                      }),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _con.videoEditorController!.rotate90Degrees(RotateDirection.left),
                child: Icon(Icons.rotate_left, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _con.videoEditorController!.rotate90Degrees(RotateDirection.right),
                child: Icon(Icons.rotate_right, color: Colors.white),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: openCropScreen,
                child: Icon(
                  Icons.crop,
                  color: Colors.white,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _con.showEditorDone,
              builder: (_, bool showOrNot, __) => showOrNot
                  ? Expanded(
                      child: InkWell(
                        onTap: () {
                          print(
                              "_con.videoEditorController!.minTrim ${_con.videoEditorController!.minTrim} ||  _con.videoEditorController!.maxTrim ${_con.videoEditorController!.maxTrim} || _con.videoEditorController!.minCrop ${_con.videoEditorController!.minCrop} || _con.videoEditorController!.maxCrop ${_con.videoEditorController!.maxCrop} || _con.videoEditorController!.rotation ${_con.videoEditorController!.rotation}");
                          if (_con.videoEditorController!.minTrim > 0.0 ||
                              _con.videoEditorController!.maxTrim < 0.99 ||
                              _con.videoEditorController!.minCrop != Offset.zero ||
                              _con.videoEditorController!.maxCrop != Offset(1.0, 1.0) ||
                              _con.videoEditorController!.rotation > 0) {
                            _con.nextStep(context);
                          } else {
                            Fluttertoast.showToast(msg: "First make few changes to save");
                          }
                        },
                        child: "Done".text.color(Colors.white).make().centered(),
                      ),
                    )
                  : Container(),
            ),
            /*_con.videoEditorController!.video.value.duration.inSeconds <= videoRepo.selectedVideoLength.value
                ? */
            Expanded(
              child: InkWell(
                onTap: () async {
                  print("_con.videoEditorController.video.dataSource ${_con.videoEditorController!.video.dataSource}");
                  String filePath = "";
                  if (_con.videoEditorController!.video.value.duration.inSeconds >= videoRepo.selectedVideoLength.value) {
                    await _con.trimVideoToMaxLength(_con.videoEditorController!.video.dataSource);
                    filePath = videoRepo.outputVideoPath.value;
                  } else {
                    filePath = _con.videoEditorController!.video.dataSource;
                  }
                  _con.previewVideoController = VideoPlayerController.file(File(filePath));
                  _con.previewVideoController!.initialize().then((value) async {
                    setState(() {});
                    _con.previewVideoController!.play();
                    _con.previewVideoController!.setLooping(true);
                    _con.showTextFilter.value = true;
                    _con.showTextFilter.notifyListeners();
                    /*videoRepo.outputVideoPath.value = File(_con.videoEditorController.video.dataSource).path;
                    videoRepo.outputVideoPath.notifyListeners();*/
                    _con.openStoriesEditor(context);
                  });
                },
                child: "Skip".text.color(Colors.white).make().centered(),
              ),
            ) /*: Container()*/,
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) => [duration.inMinutes.remainder(60).toString().padLeft(2, '0'), duration.inSeconds.remainder(60).toString().padLeft(2, '0')].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: _con.videoEditorController!.video,
        builder: (_, __) {
          final duration = _con.videoEditorController!.video.value.duration.inSeconds;
          final pos = _con.videoEditorController!.trimPosition * duration;
          final start = _con.videoEditorController!.minTrim * duration;
          final end = _con.videoEditorController!.maxTrim * duration;

          return Padding(
            padding: Margin.horizontal(_con.height / 4),
            child: Row(
              children: [
                TextDesigned(formatter(Duration(seconds: pos.toInt())), color: settingRepo.setting.value.textColor),
                Expanded(child: SizedBox()),
                OpacityTransition(
                  visible: !_con.videoEditorController!.isTrimming,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextDesigned(
                        "Start:",
                        color: settingRepo.setting.value.textColor,
                      ),
                      SizedBox(width: 2),
                      TextDesigned(
                        formatter(
                          Duration(
                            seconds: start.toInt(),
                          ),
                        ),
                        color: settingRepo.setting.value.textColor,
                      ),
                      SizedBox(width: 10),
                      TextDesigned(
                        "End:",
                        color: settingRepo.setting.value.textColor,
                      ),
                      SizedBox(width: 2),
                      TextDesigned(
                        formatter(
                          Duration(
                            seconds: end.toInt(),
                          ),
                        ),
                        color: settingRepo.setting.value.textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: Margin.vertical(_con.height / 5),
        child: TrimSlider(
            child: TrimTimeline(controller: _con.videoEditorController!, margin: EdgeInsets.only(top: 10)),
            controller: _con.videoEditorController!,
            height: _con.height,
            horizontalMargin: _con.height / 5),
      )
    ];
  }
}

//-----------------//
//CROP VIDEO SCREEN//
//-----------------//
class CropScreen extends StatefulWidget {
  late VideoEditorController controller;
  CropScreen({Key? key, required this.controller}) : super(key: key);
  @override
  State<StatefulWidget> createState() => _CropScreenState();
}

class _CropScreenState extends StateMVC<CropScreen> {
  VideoRecorderController _con = VideoRecorderController();
  // late VideoEditorController controller;
  _CropScreenState() : super(VideoRecorderController()) {
    _con = VideoRecorderController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      key: _con.videoEditorViewKey,
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.controller.rotate90Degrees(RotateDirection.left),
                child: Icon(Icons.rotate_left),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.controller.rotate90Degrees(RotateDirection.right),
                child: Icon(Icons.rotate_right),
              ),
            )
          ]),
          SizedBox(height: 5),
          Expanded(
            child: AnimatedInteractiveViewer(
              maxScale: 2.4,
              child: CropGridViewer(
                controller: widget.controller,
                horizontalMargin: 0,
              ),
            ),
          ),
          SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: SplashTap(
                onTap: context.goBack,
                child: Center(
                  child: TextDesigned(
                    "CANCEL",
                    bold: true,
                    color: settingRepo.setting.value.textColor,
                  ),
                ),
              ),
            ),
            buildSplashTap("16:9", 16 / 9, padding: Margin.horizontal(10)),
            buildSplashTap("1:1", 1 / 1),
            buildSplashTap("4:5", 4 / 5, padding: Margin.horizontal(10)),
            buildSplashTap("NO", null, padding: Margin.right(10)),
            Expanded(
              child: SplashTap(
                onTap: () {
                  //2 WAYS TO UPDATE CROP
                  //WAY 1:
                  widget.controller.updateCrop();
                  /*WAY 2:
                  controller.minCrop = controller.cacheMinCrop;
                  controller.maxCrop = controller.cacheMaxCrop;
                  */
                  context.goBack();
                },
                child: Center(
                  child: TextDesigned(
                    "OK",
                    bold: true,
                    color: settingRepo.setting.value.textColor,
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget buildSplashTap(
    String title,
    double? aspectRatio, {
    EdgeInsetsGeometry? padding,
  }) {
    return SplashTap(
      onTap: () => widget.controller.preferredCropAspectRatio = aspectRatio,
      child: Padding(
        padding: padding ?? Margin.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.aspect_ratio, color: Colors.white),
            TextDesigned(
              title,
              bold: true,
              color: settingRepo.setting.value.textColor,
            ),
          ],
        ),
      ),
    );
  }
}
