import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';

class AppSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;

  var searchMode = 0.obs;

  void Function()? _animationListener;

  AppSearchController() {
    tabController =
        TabController(length: Sites.supportSites.length, vsync: this);
    _animationListener = () {
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
    };
    tabController.animation?.addListener(_animationListener!);
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

  void doSearch() {
    if (searchController.text.isEmpty) {
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
    if (_animationListener != null) {
      tabController.animation?.removeListener(_animationListener!);
    }
    tabController.dispose();
    for (var site in Sites.supportSites) {
      Get.delete<SearchListController>(tag: site.id);
    }
    super.onClose();
  }
}
