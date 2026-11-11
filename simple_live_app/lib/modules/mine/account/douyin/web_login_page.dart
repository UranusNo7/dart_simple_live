import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class DouyinWebLoginPage extends GetView<DouyinWebLoginController> {
  const DouyinWebLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          controller.stop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("抖音网页登录"),
          leading: BackButton(onPressed: controller.cancelAndClose),
          actions: [
            TextButton(
              onPressed: () => controller.cancelAndClose(
                DouyinWebLoginController.manualCookieResult,
              ),
              child: const Text("手动输入Cookie"),
            ),
          ],
        ),
        body: !DouyinWebLoginController.isSupportedPlatform
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "当前平台不支持内置网页登录，请返回使用“Cookie登录”手动填写。",
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Obx(() {
                if (!controller.webViewCheckDone.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!controller.webViewReady.value) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "未检测到 WebView2 运行时，网页登录不可用。请安装 Microsoft Edge WebView2 Runtime 后重试，或使用右上角手动输入 Cookie。",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => controller.cancelAndClose(
                              DouyinWebLoginController.manualCookieResult,
                            ),
                            child: const Text("手动输入 Cookie"),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildWebView(context);
              }),
      ),
    );
  }

  Widget _buildWebView(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Text(
            "在官方页面点“登录”完成登录；检测到登录 Cookie 后自动保存。页面无法加载时可点右上角手动输入。",
            style: TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: InAppWebView(
            onWebViewCreated: controller.onWebViewCreated,
            onLoadStop: controller.onLoadStop,
            onReceivedError: (webController, request, error) {
              if (request.isForMainFrame ?? false) {
                SmartDialog.showToast("网页加载失败，可返回使用 Cookie 手动登录");
              }
            },
            initialSettings: InAppWebViewSettings(
              userAgent: DouyinSite.kDefaultUserAgent,
              javaScriptEnabled: true,
              domStorageEnabled: true,
              thirdPartyCookiesEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (webController, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri == null) {
                return NavigationActionPolicy.CANCEL;
              }
              if (uri.scheme == "http" ||
                  uri.scheme == "https" ||
                  uri.scheme == "about") {
                return NavigationActionPolicy.ALLOW;
              }
              // 不处理 douyin:// 等应用 scheme，避免绕过官方登录流程。
              return NavigationActionPolicy.CANCEL;
            },
          ),
        ),
      ],
    );
  }
}
