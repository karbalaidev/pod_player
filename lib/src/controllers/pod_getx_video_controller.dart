import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as _html;

import '../../pod_player.dart';
import '../utils/logger.dart';
import '../utils/vimeo_video_api.dart';

part 'pod_base_controller.dart';
part 'pod_gestures_controller.dart';
part 'pod_video_controller.dart';
part 'pod_ui_controller.dart';
part 'pod_vimeo_controller.dart';

class FlGetXVideoController extends _FlUiController {
  ///main videoplayer controller
  VideoPlayerController? get videoCtr => _videoCtr;

  ///podVideoPlayer state notifier
  FlVideoState get podVideoState => _podVideoState;

  ///vimeo or general --video player type
  FlVideoPlayerType get videoPlayerType => _videoPlayerType;

  String get currentPaybackSpeed => _currentPaybackSpeed;

  ///
  Duration get videoDuration => _videoDuration;

  ///
  Duration get videoPosition => _videoPosition;

  int? vimeoVideoQuality;
  bool controllerInitialized = false;
  late PlayVideoFrom playVideoFrom;
  void config({
    required PlayVideoFrom playVideoFrom,
    bool isLooping = false,
    bool autoPlay = true,
    int? vimeoVideoQuality,
  }) {
    this.playVideoFrom = playVideoFrom;
    this.vimeoVideoQuality = vimeoVideoQuality;
    _videoPlayerType = playVideoFrom.playerType;
    this.autoPlay = autoPlay;
    this.isLooping = isLooping;
  }

  ///*init
  Future<void> videoInit() async {
    ///
    // checkPlayerType();
    podLog(_videoPlayerType.toString());
    try {
      await _initializePlayer();
      await _videoCtr?.initialize();
      _videoDuration = _videoCtr?.value.duration ?? Duration.zero;
      await setLooping(isLooping);
      _videoCtr?.addListener(videoListner);
      addListenerId('podVideoState', podStateListner);

      checkAutoPlayVideo();
      controllerInitialized = true;
      update();

      update(['update-all']);
      // ignore: unawaited_futures
      Future.delayed(const Duration(milliseconds: 600))
          .then((value) => _isWebAutoPlayDone = true);
    } catch (e) {
      podLog('ERROR ON FLVIDEOPLAYER:  $e');
      rethrow;
    }
  }

  Future<void> _initializePlayer() async {
    switch (_videoPlayerType) {
      case FlVideoPlayerType.network:

        ///
        _videoCtr = VideoPlayerController.network(
          playVideoFrom.dataSource!,
          closedCaptionFile: playVideoFrom.closedCaptionFile,
          formatHint: playVideoFrom.formatHint,
          videoPlayerOptions: playVideoFrom.videoPlayerOptions,
          httpHeaders: playVideoFrom.httpHeaders,
        );

        break;
      case FlVideoPlayerType.vimeo:

        ///
        if (playVideoFrom.dataSource != null) {
          await vimeoPlayerInit(
            quality: vimeoVideoQuality,
            videoId: playVideoFrom.dataSource,
          );
        } else {
          await vimeoPlayerInit(
            quality: vimeoVideoQuality,
            vimeoUrls: playVideoFrom.vimeoUrls,
          );
        }

        _videoCtr = VideoPlayerController.network(
          _vimeoVideoUrl,
          closedCaptionFile: playVideoFrom.closedCaptionFile,
          formatHint: playVideoFrom.formatHint,
          videoPlayerOptions: playVideoFrom.videoPlayerOptions,
          httpHeaders: playVideoFrom.httpHeaders,
        );

        break;
      case FlVideoPlayerType.asset:

        ///
        _videoCtr = VideoPlayerController.asset(
          playVideoFrom.dataSource!,
          closedCaptionFile: playVideoFrom.closedCaptionFile,
          package: playVideoFrom.package,
          videoPlayerOptions: playVideoFrom.videoPlayerOptions,
        );
        break;
      case FlVideoPlayerType.file:

        ///
        _videoCtr = VideoPlayerController.file(
          playVideoFrom.file!,
          closedCaptionFile: playVideoFrom.closedCaptionFile,
          videoPlayerOptions: playVideoFrom.videoPlayerOptions,
        );

        break;
    }

  }

  ///Listning on keyboard events
  void onKeyBoardEvents({
    required RawKeyEvent event,
    required BuildContext appContext,
    required String tag,
  }) {
    if (kIsWeb) {
      if (event.isKeyPressed(LogicalKeyboardKey.space)) {
        togglePlayPauseVideo();
        return;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.keyM)) {
        toggleMute();
        return;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        onLeftDoubleTap();
        return;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        onRightDoubleTap();
        return;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.keyF) &&
          event.logicalKey.keyLabel == 'F') {
        toggleFullScreenOnWeb(appContext, tag);
      }
      if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
        if (isFullScreen) {
          _html.document.exitFullscreen();
          if (!isWebPopupOverlayOpen) disableFullScreen(appContext, tag);
        }
      }

      return;
    }
  }

  void toggleFullScreenOnWeb(BuildContext context, String tag) {
    if (isFullScreen) {
      _html.document.exitFullscreen();
      if (!isWebPopupOverlayOpen) disableFullScreen(context, tag);
    } else {
      _html.document.documentElement?.requestFullscreen();
      enableFullScreen(tag);
    }
  }

  ///this func will listne to update id `_podVideoState`
  void podStateListner() {
    podLog(_podVideoState.toString());
    switch (_podVideoState) {
      case FlVideoState.playing:
        playVideo(true);
        break;
      case FlVideoState.paused:
        playVideo(false);
        break;
      case FlVideoState.loading:
        isShowOverlay(true);
        break;
      case FlVideoState.error:
        playVideo(false);
        break;
    }
  }

  ///checkes wether video should be `autoplayed` initially
  void checkAutoPlayVideo() {
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
      if (autoPlay && (isVideoUiBinded ?? false)) {
        if (kIsWeb) await _videoCtr?.setVolume(0);
        podVideoStateChanger(FlVideoState.playing);
      } else {
        podVideoStateChanger(FlVideoState.paused);
      }
    });
  }

  Future<void> changeVideo({
    required PlayVideoFrom playVideoFrom,
    required FlVideoPlayerConfig playerConfig,
  }) async {
    _videoCtr?.removeListener(videoListner);
    podVideoStateChanger(FlVideoState.paused);
    podVideoStateChanger(FlVideoState.loading);
    keyboardFocusWeb?.removeListener(keyboadListner);
    removeListenerId('podVideoState', podStateListner);
    _isWebAutoPlayDone = false;
    config(
      playVideoFrom: playVideoFrom,
      autoPlay: playerConfig.autoPlay,
      isLooping: playerConfig.isLooping,
    );
    keyboardFocusWeb?.requestFocus();
    keyboardFocusWeb?.addListener(keyboadListner);
    await videoInit();
  }
}