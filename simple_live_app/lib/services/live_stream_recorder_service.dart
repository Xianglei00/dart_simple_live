import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';

/// 安卓端直播流录制服务
/// 直接抓取抖音返回的 FLV 原始数据流并保存到本地文件
/// 默认录制最高画质（qualites[0]）
class LiveStreamRecorderService extends GetxService {
  static LiveStreamRecorderService get instance =>
      Get.find<LiveStreamRecorderService>();

  /// 是否正在录制
  var isRecording = false.obs;

  /// 录制时长（秒）
  var recordSeconds = 0.obs;

  CancelToken? _cancelToken;
  Timer? _timer;
  String? _currentFilePath;

  /// 录制时长文本（mm:ss）
  String get recordTimeText {
    var m = (recordSeconds.value ~/ 60).toString().padLeft(2, '0');
    var s = (recordSeconds.value % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  /// 开始录制直播流
  Future<bool> start() async {
    if (isRecording.value) return true;
    if (!Platform.isAndroid) {
      SmartDialog.showToast("流录制功能仅支持安卓端");
      return false;
    }

    try {
      // 从当前直播间控制器获取最高画质流地址
      if (!Get.isRegistered<LiveRoomController>()) {
        SmartDialog.showToast("未在直播间中，无法录制");
        return false;
      }
      final controller = Get.find<LiveRoomController>();
      if (controller.qualites.isEmpty) {
        SmartDialog.showToast("暂无可用画质，无法录制");
        return false;
      }

      // qualites 已按 sort 降序排列，[0] 即最高画质
      final bestQuality = controller.qualites.first;
      final urls = bestQuality.data as List;
      if (urls.isEmpty) {
        SmartDialog.showToast("无法获取流地址");
        return false;
      }

      // 优先使用 FLV（urls[0]），备选 HLS
      String streamUrl = urls[0].toString();
      Log.logPrint("[录制] 最高画质: ${bestQuality.quality}, FLV: $streamUrl");

      // 构建保存路径
      final dir = await getApplicationDocumentsDirectory();
      final recordDir = Directory("${dir.path}/Recordings");
      if (!await recordDir.exists()) {
        await recordDir.create(recursive: true);
      }

      final roomTitle = controller.detail.value?.title ?? "live";
      // 清理文件名中的非法字符
      final safeTitle = roomTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = "${recordDir.path}/${safeTitle}_$timestamp.flv";
      _currentFilePath = filePath;

      // 准备 headers
      final headers = <String, dynamic>{
        "User-Agent":
            "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Referer": "https://live.douyin.com/",
      };
      // 合并播放所需的 headers（如果有自定义 headers）
      if (controller.playHeaders != null) {
        headers.addAll(controller.playHeaders!);
      }

      _cancelToken = CancelToken();

      // 启动计时器
      recordSeconds.value = 0;
      isRecording.value = true;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordSeconds.value++;
      });

      SmartDialog.showToast("开始录制（${bestQuality.quality}）");

      // 异步下载流
      _startDownload(streamUrl, headers, filePath);

      return true;
    } catch (e) {
      Log.logPrint("[录制] 启动失败: $e");
      SmartDialog.showToast("录制启动失败");
      return false;
    }
  }

  /// 使用 dio 流式下载 FLV 直播流
  Future<void> _startDownload(
    String url,
    Map<String, dynamic> headers,
    String filePath,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 30),
    ));

    RandomAccessFile? raf;
    try {
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
        cancelToken: _cancelToken,
      );

      raf = File(filePath).openSync(mode: FileMode.write);

      await for (final chunk in response.data.stream) {
        raf.writeFromSync(chunk);
      }

      Log.logPrint("[录制] 流正常结束，文件: $filePath");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        Log.logPrint("[录制] 用户主动停止");
      } else {
        Log.logPrint("[录制] 下载异常: ${e.type} - ${e.message}");
      }
    } catch (e) {
      Log.logPrint("[录制] 下载错误: $e");
    } finally {
      raf?.closeSync();
      _cleanup();
    }
  }

  /// 停止录制
  Future<String?> stop() async {
    if (!isRecording.value) return null;

    _cancelToken?.cancel("用户停止录制");
    _timer?.cancel();

    final path = _currentFilePath;
    _cleanup();

    // 延迟一下确保文件写入完成
    await Future.delayed(const Duration(milliseconds: 500));

    if (path != null && File(path).existsSync()) {
      final size = File(path).lengthSync();
      final sizeMB = (size / 1024 / 1024).toStringAsFixed(1);
      SmartDialog.showToast("录制已保存（${sizeMB}MB）");
      Log.logPrint("[录制] 已保存: $path (${sizeMB}MB)");
      return path;
    } else {
      SmartDialog.showToast("录制已停止");
      return null;
    }
  }

  void _cleanup() {
    _cancelToken = null;
    _timer?.cancel();
    _timer = null;
    isRecording.value = false;
    recordSeconds.value = 0;
    _currentFilePath = null;
  }

  /// 切换录制状态
  Future<void> toggle() async {
    if (isRecording.value) {
      await stop();
    } else {
      await start();
    }
  }

  @override
  void onClose() {
    _cancelToken?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
