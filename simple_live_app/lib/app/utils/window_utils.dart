import 'dart:io';

import 'package:window_manager/window_manager.dart';

/// 桌面端窗口全屏工具
///
/// 修复 Windows 下最大化状态直接 setFullScreen 导致退出全屏后
/// 窗口位置/尺寸错位的问题（window_manager 已知问题）：
/// 进入全屏前先取消最大化并记录状态，退出全屏后再还原最大化。
class WindowUtils {
  static bool _wasMaximized = false;

  /// 进入全屏（仅桌面端生效）
  static Future<void> enterFullScreen() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    if (await windowManager.isMaximized()) {
      _wasMaximized = true;
      await windowManager.unmaximize();
    }
    await windowManager.setFullScreen(true);
  }

  /// 退出全屏（仅桌面端生效），并还原进入前的最大化状态
  static Future<void> exitFullScreen() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    if (!await windowManager.isFullScreen()) return;
    await windowManager.setFullScreen(false);
    if (_wasMaximized) {
      _wasMaximized = false;
      await windowManager.maximize();
    }
  }
}
