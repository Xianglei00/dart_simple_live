import 'dart:convert';

class LiveRoomItem {
  /// 房间ID
  final String roomId;

  /// 标题
  final String title;

  /// 封面
  final String cover;

  /// 用户名
  final String userName;

  /// 人气/在线人数
  final int online;

  /// 抖音号(unique_id)，仅抖音平台有值
  final String? uniqueId;

  /// 主播 secUid，仅抖音平台有值
  final String? secUid;
  LiveRoomItem({
    required this.roomId,
    required this.title,
    required this.cover,
    required this.userName,
    this.online = 0,
    this.uniqueId,
    this.secUid,
  });

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "title": title,
      "cover": cover,
      "userName": userName,
      "online": online,
      "uniqueId": uniqueId,
      "secUid": secUid,
    });
  }
}
