import 'dart:async';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';

class DouyinWebLoginController extends BaseController {
  /// 只读取 www.douyin.com 实际可用的 Cookie，避免把 live/sso 专有会话
  /// 在尚未同步到搜索域时误判为已登录。
  static const String loginUrl = "https://www.douyin.com/";

  /// 从网页登录页返回账号页时，用该结果通知账号页打开手动 Cookie 输入。
  static const String manualCookieResult = "manual";

  /// 检测到这些 www 登录 Cookie 后才自动保存；单独 ttwid 不算。
  static const Set<String> loginCookieNames = {
    "sessionid",
    "sessionid_ss",
  };

  static bool get isSupportedPlatform =>
      Platform.isAndroid || Platform.isWindows;

  /// Windows 先检测 WebView2 运行时，缺失时由页面引导手动输入。
  static Future<bool> isWebViewAvailable({
    bool? isWindows,
    Future<String?> Function()? getVersion,
  }) async {
    if (!(isWindows ?? Platform.isWindows)) {
      return true;
    }
    try {
      final probe = getVersion ?? () => WebViewEnvironment.getAvailableVersion();
      final version = await probe();
      return version != null && version.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  var webViewReady = false.obs;
  var webViewCheckDone = false.obs;

  CookieManager? _cookieManager;
  CookieManager get cookieManager =>
      _cookieManager ??= CookieManager.instance();
  InAppWebViewController? webViewController;

  Timer? _pollTimer;
  bool _checking = false;
  bool _finished = false;

  bool get finished => _finished;

  Future<void> prepareWebView() async {
    if (webViewCheckDone.value) {
      return;
    }
    final available = await isWebViewAvailable();
    if (isClosed) {
      return;
    }
    webViewReady.value = available;
    webViewCheckDone.value = true;
  }

  @override
  void onInit() {
    prepareWebView();
    super.onInit();
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(loginUrl)));
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) {
    if (_finished) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      checkLoginOnce();
    });
    checkLoginOnce();
  }

  /// 轮询检查登录 Cookie，成功后只保存并退出一次。
  Future<void> checkLoginOnce() async {
    if (_finished || _checking) {
      return;
    }
    _checking = true;
    try {
      final cookie = await readLoginCookie();
      // 用户已关闭页面时，迟到结果不能保存或导航。
      if (_finished || cookie == null) {
        return;
      }
      _finished = true;
      _pollTimer?.cancel();
      _pollTimer = null;
      saveLoginCookie(cookie);
      closeLoginPage();
    } finally {
      _checking = false;
    }
  }

  Future<String?> readLoginCookie() async {
    try {
      return buildLoginCookie(await readCookies(WebUri(loginUrl)));
    } catch (_) {
      return null;
    }
  }

  /// 按传入顺序去重（先到先得），并要求至少一个 www 登录 Cookie 非空。
  static String? buildLoginCookie(Iterable<Cookie> cookies) {
    final values = <String, String>{};
    for (final cookie in cookies) {
      final name = cookie.name.trim();
      final value = cookie.value?.toString().trim() ?? "";
      if (name.isEmpty || value.isEmpty || values.containsKey(name)) {
        continue;
      }
      values[name] = value;
    }
    if (!loginCookieNames.any((name) => (values[name] ?? "").isNotEmpty)) {
      return null;
    }
    return values.entries.map((entry) => "${entry.key}=${entry.value}").join("; ");
  }

  Future<List<Cookie>> readCookies(WebUri url) {
    return cookieManager.getCookies(url: url);
  }

  void saveLoginCookie(String cookie) {
    DouyinAccountService.instance.setCookie(cookie);
    SmartDialog.showToast("检测到登录 Cookie，已保存；实际搜索可用性以平台登录态为准");
  }

  void closeLoginPage() {
    Get.back();
  }

  /// 停止轮询并标记已结束，不导航；供返回/系统 back/onClose 复用。
  void stop() {
    _finished = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 关闭页面（可带返回值）；取消后不再保存 Cookie。
  void cancelAndClose([Object? result]) {
    stop();
    Get.back(result: result);
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
