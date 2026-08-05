import 'dart:async';
import 'dart:io';

import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// 安卓端录屏服务
/// 基于系统 MediaProjection 录制屏幕，同时录制麦克风声音
/// （可录到直播外放的声音，无需耳机场景）
/// 录制的视频保存在系统 Movies/ScreenRecordings 目录，相册可见
class ScreenRecorderService extends GetxService {
  static ScreenRecorderService get instance =>
      Get.find<ScreenRecorderService>();

  /// 是否正在录制
  var isRecording = false.obs;

  /// 录制时长（秒）
  var recordSeconds = 0.obs;

  Timer? _timer;

  /// 录制时长文本（mm:ss）
  String get recordTimeText {
    var m = (recordSeconds.value ~/ 60).toString().padLeft(2, '0');
    var s = (recordSeconds.value % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  /// 开始录屏
  Future<bool> start() async {
    if (isRecording.value) return true;
    if (!Platform.isAndroid) {
      SmartDialog.showToast("录屏功能仅支持安卓端");
      return false;
    }

    // 通知权限（Android 13+ 前台服务通知必需）
    var notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      notificationStatus = await Permission.notification.request();
    }
    if (notificationStatus.isDenied) {
      SmartDialog.showToast("需要通知权限才能录屏");
      return false;
    }

    // 麦克风权限（录制声音需要）
    var micStatus = await Permission.microphone.status;
    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
      micStatus = await Permission.microphone.request();
    }
    if (micStatus.isDenied) {
      SmartDialog.showToast("需要麦克风权限才能录制声音");
      return false;
    }

    var name = "simple_live_${DateTime.now().millisecondsSinceEpoch}";
    var started = false;
    try {
      // 录制屏幕 + 麦克风声音
      started = await FlutterScreenRecording.startRecordScreenAndAudio(
        name,
        titleNotification: "Simple Live 录屏中",
        messageNotification: "正在录制直播画面",
      );
    } catch (e) {
      SmartDialog.showToast("录屏启动失败");
      return false;
    }

    if (started) {
      isRecording.value = true;
      recordSeconds.value = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordSeconds.value++;
      });
      SmartDialog.showToast("开始录屏");
    } else {
      SmartDialog.showToast("录屏启动失败，请重试");
    }
    return started;
  }

  /// 停止录屏
  /// 注意：flutter_screen_recording 2.0.25 停止时可能拿不到文件路径，
  /// 但视频文件本身会正常保存到系统 Movies/ScreenRecordings 目录
  Future<String?> stop() async {
    if (!isRecording.value) return null;
    _timer?.cancel();
    var path = "";
    try {
      path = await FlutterScreenRecording.stopRecordScreen;
    } catch (e) {
      // 忽略，录屏文件仍会保存
    }
    isRecording.value = false;
    recordSeconds.value = 0;
    if (path.isNotEmpty) {
      SmartDialog.showToast("录屏已保存：$path");
    } else {
      SmartDialog.showToast("录屏已保存至系统相册（Movies/ScreenRecordings）");
    }
    return path.isEmpty ? null : path;
  }

  /// 切换录屏状态
  Future<void> toggle() async {
    if (isRecording.value) {
      await stop();
    } else {
      await start();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
