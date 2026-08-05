import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// 安卓端录屏服务
/// 基于系统 MediaProjection 录制屏幕，Android 10+ 可录制内部音频（直播声音）
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

    var name = "simple_live_${DateTime.now().millisecondsSinceEpoch}";
    var started = false;
    try {
      if (await _isAndroid10Plus()) {
        // Android 10+ 录制内部音频（直播声音）
        started = await FlutterScreenRecording.startRecordScreenWithInternalAudio(
          name,
          titleNotification: "Simple Live 录屏中",
          messageNotification: "正在录制直播画面",
        );
      } else {
        // 低版本仅录制画面
        started = await FlutterScreenRecording.startRecordScreen(
          name,
          titleNotification: "Simple Live 录屏中",
          messageNotification: "正在录制直播画面",
        );
      }
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

  /// 停止录屏，返回视频文件路径
  Future<String?> stop() async {
    if (!isRecording.value) return null;
    _timer?.cancel();
    var path = "";
    try {
      path = await FlutterScreenRecording.stopRecordScreen;
    } catch (e) {
      SmartDialog.showToast("停止录屏失败");
    }
    isRecording.value = false;
    recordSeconds.value = 0;
    if (path.isNotEmpty) {
      SmartDialog.showToast("录屏已保存：$path");
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

  Future<bool> _isAndroid10Plus() async {
    try {
      var info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt >= 29;
    } catch (e) {
      return false;
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
