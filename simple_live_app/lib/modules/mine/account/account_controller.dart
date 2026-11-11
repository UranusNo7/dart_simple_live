import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AccountController extends GetxController {
  static String normalizeDouyinCookieInput(String input) {
    final value = input.trim();
    return value.isEmpty || value.contains('=') ? value : 'ttwid=$value';
  }

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result = await Utils.showAlertDialog("确定要清除自定义抖音 Cookie 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
      }
    } else {
      doDouyinCookieConfig();
    }
  }

  void doDouyinCookieConfig() {
    var controller = TextEditingController(
      text: DouyinAccountService.instance.cookie,
    );

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "观看直播可使用默认 ttwid；搜索需要有效的登录 Cookie。\n请填写浏览器登录抖音后的完整 Cookie 请求头值，也兼容单独的 ttwid 值。Cookie 含登录凭据，请勿分享。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "完整 Cookie 或 ttwid 值（留空使用默认值）",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // 提取 ttwid 的值部分（去掉 "ttwid=" 前缀）
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6); // 去掉 "ttwid="
                  }
                  controller.text = defaultValue;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              final cookie = normalizeDouyinCookieInput(controller.text);
              Get.back();
              if (cookie.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                DouyinAccountService.instance.setCookie(cookie);
                SmartDialog.showToast("Cookie 已保存，登录状态尚未验证");
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
}
