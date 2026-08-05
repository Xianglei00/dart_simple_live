import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AppSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;

  var searchMode = 0.obs;

  AppSearchController() {
    tabController =
        TabController(length: Sites.supportSites.length, vsync: this);
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (index == currentIndex) {
        return;
      }

      index = currentIndex;

      var controller =
          Get.find<SearchListController>(tag: Sites.supportSites[index].id);

      if (controller.list.isEmpty &&
          !controller.pageEmpty.value &&
          controller.keyword.isNotEmpty) {
        controller.refreshData();
      }
    });
  }

  StreamSubscription<dynamic>? streamSubscription;

  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    for (var site in Sites.supportSites) {
      Get.put(
        SearchListController(site),
        tag: site.id,
      );
    }

    super.onInit();
  }

  /// 尝试解析抖音直播间链接或房间号，成则直接跳转并返回 true
  bool _tryOpenDouyinLink(String input) {
    var text = input.trim();
    var douyinSite = Sites.allSites[Constant.kDouyin];
    if (douyinSite == null) return false;

    // 匹配完整链接: https://live.douyin.com/123456
    var urlReg = RegExp(r'(?:https?://)?live\.douyin\.com/(\d+)');
    var urlMatch = urlReg.firstMatch(text);
    if (urlMatch != null) {
      AppNavigator.toLiveRoomDetail(
          site: douyinSite, roomId: urlMatch.group(1)!);
      return true;
    }

    // 当前 Tab 为抖音时，支持直接输入纯数字房间号
    if (Sites.supportSites[index].id == Constant.kDouyin &&
        RegExp(r'^\d+$').hasMatch(text)) {
      AppNavigator.toLiveRoomDetail(site: douyinSite, roomId: text);
      return true;
    }

    // 当前 Tab 为抖音时，支持通过抖音号直达直播间
    // 抖音号一般为字母开头、字母数字组合（如 abc123）
    // 找到正在直播的直播间则直接进入；否则不拦截，走普通搜索
    if (Sites.supportSites[index].id == Constant.kDouyin &&
        RegExp(r'^[a-zA-Z][a-zA-Z0-9_.-]{0,29}$').hasMatch(text)) {
      _tryOpenByDouyinId(text, douyinSite);
    }

    return false;
  }

  /// 通过抖音号查询直播间，找到正在直播的直播间则直接进入
  Future<void> _tryOpenByDouyinId(String douyinId, Site douyinSite) async {
    try {
      var douyin = douyinSite.liveSite as DouyinSite;
      var items = await douyin.searchLiveRoomByDouyinId(douyinId);
      if (items.isNotEmpty) {
        AppNavigator.toLiveRoomDetail(
          site: douyinSite,
          roomId: items.first.roomId,
        );
      }
    } catch (e) {
      Log.logPrint("抖音号直达失败: $e");
    }
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      return;
    }
    // 尝试识别抖音直播间链接
    if (_tryOpenDouyinLink(searchController.text)) {
      return;
    }
    for (var site in Sites.supportSites) {
      var controller = Get.find<SearchListController>(tag: site.id);
      controller.clear();
      controller.keyword = searchController.text;
      controller.searchMode.value = searchMode.value;
    }
    var controller =
        Get.find<SearchListController>(tag: Sites.supportSites[index].id);
    controller.refreshData();
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    super.onClose();
  }
}