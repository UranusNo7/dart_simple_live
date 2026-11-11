import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_controller.dart';

Cookie _cookie(String name, String value) => Cookie(name: name, value: value);

class _FakeDouyinWebLoginController extends DouyinWebLoginController {
  _FakeDouyinWebLoginController(this.onReadCookies);

  final Future<List<Cookie>> Function(WebUri url) onReadCookies;
  final List<String> savedCookies = [];
  int closeCount = 0;

  @override
  Future<List<Cookie>> readCookies(WebUri url) => onReadCookies(url);

  @override
  void saveLoginCookie(String cookie) {
    savedCookies.add(cookie);
  }

  @override
  void closeLoginPage() {
    closeCount++;
  }
}

void main() {
  group('DouyinWebLoginController.buildLoginCookie', () {
    test('www Cookie 去重后拼接，只保留有效登录 Cookie', () {
      final cookie = DouyinWebLoginController.buildLoginCookie([
        _cookie('sessionid', 'www-session'),
        _cookie('sessionid', 'duplicate-session'),
        _cookie('ttwid', 'www-ttwid'),
        _cookie('sessionid_ss', 'ss-session'),
        _cookie('', 'empty-name'),
        _cookie('empty-value', ''),
      ]);

      expect(
        cookie,
        'sessionid=www-session; ttwid=www-ttwid; sessionid_ss=ss-session',
      );
    });

    test('只有 ttwid/sid_tt 或空 sessionid 不算登录成功', () {
      expect(
        DouyinWebLoginController.buildLoginCookie([
          _cookie('ttwid', 'visitor-only'),
        ]),
        isNull,
      );
      expect(
        DouyinWebLoginController.buildLoginCookie([
          _cookie('sid_tt', 'not-enough-evidence'),
        ]),
        isNull,
      );
      expect(
        DouyinWebLoginController.buildLoginCookie([
          _cookie('sessionid', ''),
          _cookie('ttwid', 'visitor-only'),
        ]),
        isNull,
      );
      expect(DouyinWebLoginController.buildLoginCookie([]), isNull);
    });
  });

  group('DouyinWebLoginController.isWebViewAvailable', () {
    test('Windows 能取到版本号时可用', () async {
      expect(
        await DouyinWebLoginController.isWebViewAvailable(
          isWindows: true,
          getVersion: () async => '120.0.2210.91',
        ),
        isTrue,
      );
    });

    test('Windows 版本为 null 或预检抛异常时不可用', () async {
      expect(
        await DouyinWebLoginController.isWebViewAvailable(
          isWindows: true,
          getVersion: () async => null,
        ),
        isFalse,
      );
      expect(
        await DouyinWebLoginController.isWebViewAvailable(
          isWindows: true,
          getVersion: () async => throw Exception("missing runtime"),
        ),
        isFalse,
      );
    });

    test('非 Windows 不调用预检', () async {
      var called = false;
      final available = await DouyinWebLoginController.isWebViewAvailable(
        isWindows: false,
        getVersion: () async {
          called = true;
          return null;
        },
      );

      expect(available, isTrue);
      expect(called, isFalse);
    });
  });

  group('DouyinWebLoginController 登录检查', () {
    test('发现 sessionid 只保存并退出一次，重复回调不再处理', () async {
      final controller = _FakeDouyinWebLoginController(
        (_) async => [_cookie('sessionid', 'test-session')],
      );

      await controller.checkLoginOnce();
      await controller.checkLoginOnce();

      expect(controller.savedCookies, hasLength(1));
      expect(controller.savedCookies.single, contains('sessionid=test-session'));
      expect(controller.closeCount, 1);
      expect(controller.finished, isTrue);
    });

    test('只有 ttwid 时不保存也不退出', () async {
      final controller = _FakeDouyinWebLoginController(
        (_) async => [_cookie('ttwid', 'visitor-only')],
      );

      await controller.checkLoginOnce();

      expect(controller.savedCookies, isEmpty);
      expect(controller.closeCount, 0);
      expect(controller.finished, isFalse);
    });

    test('只读取 www.douyin.com，live/sso 专有会话不会提前成功', () async {
      final requested = <String>[];
      final controller = _FakeDouyinWebLoginController((url) async {
        requested.add(url.toString());
        if (url.toString() == DouyinWebLoginController.loginUrl) {
          return [_cookie('ttwid', 'www-visitor')];
        }
        return [_cookie('sessionid', 'live-session')];
      });

      await controller.checkLoginOnce();

      expect(requested, [DouyinWebLoginController.loginUrl]);
      expect(controller.savedCookies, isEmpty);
      expect(controller.closeCount, 0);
    });

    test('页面关闭后迟到的 Cookie 不再保存或导航', () async {
      final completer = Completer<List<Cookie>>();
      final controller = _FakeDouyinWebLoginController(
        (_) => completer.future,
      );

      final pending = controller.checkLoginOnce();
      controller.stop();
      completer.complete([_cookie('sessionid', 'late-session')]);
      await pending;

      expect(controller.finished, isTrue);
      expect(controller.savedCookies, isEmpty);
      expect(controller.closeCount, 0);
    });

    test('并发重复回调只保存并退出一次', () async {
      final completer = Completer<List<Cookie>>();
      final controller = _FakeDouyinWebLoginController(
        (_) => completer.future,
      );

      final first = controller.checkLoginOnce();
      final second = controller.checkLoginOnce();
      completer.complete([_cookie('sessionid', 'test-session')]);
      await Future.wait([first, second]);

      expect(controller.savedCookies, hasLength(1));
      expect(controller.closeCount, 1);
    });
  });
}
