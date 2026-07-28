import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

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
      // if (Sites.supportSites[index].id == Constant.kDouyin) {
      //   return;
      // }

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
      // if (site.id == Constant.kDouyin) {
      //   Get.put(DouyinSearchController(site));
      // } else {
      Get.put(
        SearchListController(site),
        tag: site.id,
      );
      //}
    }

    super.onInit();
  }

  /// 尝试解析抖音直播间链接，成功则直接跳转并返回 true
  bool _tryOpenDouyinLink(String input) {
    // 匹配 https://live.douyin.com/123456 或 live.douyin.com/123456
    var regExp = RegExp(r'(?:https?://)?live\.douyin\.com/(\d+)');
    var match = regExp.firstMatch(input.trim());
    if (match != null) {
      var roomId = match.group(1)!;
      var douyinSite = Sites.allSites[Constant.kDouyin];
      if (douyinSite != null) {
        AppNavigator.toLiveRoomDetail(site: douyinSite, roomId: roomId);
        return true;
      }
    }
    return false;
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
      // if (site.id == Constant.kDouyin) {
      //   var controller = Get.find<DouyinSearchController>();
      //   controller.keyword = searchController.text;
      //   controller.searchMode.value = searchMode.value;
      //   controller.reloadWebView();
      // } else {
      var controller = Get.find<SearchListController>(tag: site.id);
      controller.clear();
      controller.keyword = searchController.text;
      controller.searchMode.value = searchMode.value;
      //}
    }
    // if (Sites.supportSites[index].id != Constant.kDouyin) {
    var controller =
        Get.find<SearchListController>(tag: Sites.supportSites[index].id);
    controller.refreshData();
    //}
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    super.onClose();
  }
}
