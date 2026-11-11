import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/mine/parse/douyin_room_input.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/modules/search/search_list_view.dart';

class _CapturingSearchListController extends SearchListController {
  _CapturingSearchListController(Site site) : super(site);

  final List<String> captured = [];

  @override
  void navigateToRoom(String roomId) {
    captured.add(roomId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DouyinRoomInput', () {
    test('纯数字房间号直接返回且不发起网络请求', () async {
      var redirectCalls = 0;
      final roomId = await DouyinRoomInput.resolveRoomId(
        " 906466692449 ",
        followRedirect: (_) async {
          redirectCalls++;
          return null;
        },
      );

      expect(roomId, "906466692449");
      expect(redirectCalls, 0);
    });

    test('live.douyin.com 长链和分享文案直接解析', () async {
      var redirectCalls = 0;
      final roomId = await DouyinRoomInput.resolveRoomId(
        "【直播】主播正在直播 https://live.douyin.com/123456789?from=share 复制此链接",
        followRedirect: (_) async {
          redirectCalls++;
          return null;
        },
      );

      expect(roomId, "123456789");
      expect(redirectCalls, 0);
    });

    test('webcast reflow 临时房间链接解析', () async {
      final roomId = await DouyinRoomInput.resolveRoomId(
        "https://webcast.amemv.com/webcast/reflow/7307189033105034023?xxx=1",
      );

      expect(roomId, "7307189033105034023");
    });

    test('v.douyin.com 短链跟随一次跳转到直播页', () async {
      var redirectCalls = 0;
      final roomId = await DouyinRoomInput.resolveRoomId(
        "https://v.douyin.com/abc123/",
        followRedirect: (_) async {
          redirectCalls++;
          return "https://live.douyin.com/123456";
        },
      );

      expect(roomId, "123456");
      expect(redirectCalls, 1);
    });

    test('短链多跳仍限制在官方域', () async {
      var redirectCalls = 0;
      final roomId = await DouyinRoomInput.resolveRoomId(
        "https://v.douyin.com/a/",
        followRedirect: (_) async {
          redirectCalls++;
          return redirectCalls == 1
              ? "https://v.douyin.com/b/"
              : "https://live.douyin.com/987654";
        },
      );

      expect(roomId, "987654");
      expect(redirectCalls, 2);
    });

    test('短链超过最大跳转次数返回空', () async {
      var redirectCalls = 0;
      final roomId = await DouyinRoomInput.resolveRoomId(
        "https://v.douyin.com/a/",
        followRedirect: (_) async {
          redirectCalls++;
          return "https://v.douyin.com/b/";
        },
      );

      expect(roomId, isNull);
      expect(redirectCalls, DouyinRoomInput.maxRedirects);
    });

    test('短链无 Location 或网络异常返回空', () async {
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://v.douyin.com/a/",
          followRedirect: (_) async => null,
        ),
        isNull,
      );
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://v.douyin.com/a/",
          followRedirect: (_) async => throw Exception("network"),
        ),
        isNull,
      );
    });

    test('短链跳转到非官方域返回空', () async {
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://v.douyin.com/a/",
          followRedirect: (_) async => "https://evil.example.com/live/1",
        ),
        isNull,
      );
    });

    test('直播路径必须是完整数字，可带末尾斜杠', () async {
      expect(
        await DouyinRoomInput.resolveRoomId("https://live.douyin.com/123/"),
        "123",
      );
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://live.douyin.com/123/extra",
        ),
        isNull,
      );
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://webcast.amemv.com/webcast/reflow/456/",
        ),
        "456",
      );
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://webcast.amemv.com/webcast/reflow/456/extra",
        ),
        isNull,
      );
    });

    test('短链跳转到非 http(s) scheme 拒绝', () async {
      expect(
        await DouyinRoomInput.resolveRoomId(
          "https://v.douyin.com/a/",
          followRedirect: (_) async => "ftp://live.douyin.com/123",
        ),
        isNull,
      );
    });

    test('只有 3xx 状态才读取 Location', () {
      expect(DouyinRoomInput.isRedirectStatus(302), isTrue);
      expect(DouyinRoomInput.isRedirectStatus(307), isTrue);
      expect(DouyinRoomInput.isRedirectStatus(200), isFalse);
      expect(DouyinRoomInput.isRedirectStatus(400), isFalse);
      expect(DouyinRoomInput.isRedirectStatus(null), isFalse);
    });

    test('evil 域名、个人主页、视频页、非法直播路径不误判', () async {
      for (final input in [
        "https://evil.example.com/live.douyin.com/123",
        "https://www.douyin.com/user/abc",
        "https://www.douyin.com/video/123",
        "https://live.douyin.com/user/abc",
        "https://live.douyin.com/",
        "not a room",
      ]) {
        expect(
          await DouyinRoomInput.resolveRoomId(input),
          isNull,
          reason: input,
        );
      }
    });
  });

  group('SearchListController 抖音直达入口', () {
    test('解析成功后调用真实导航入口，取消和非法输入不导航', () async {
      final controller = _CapturingSearchListController(
        Sites.allSites[Constant.kDouyin]!,
      );

      expect(
        await controller.submitDouyinRoomInput("123456"),
        "123456",
      );
      expect(controller.captured, ["123456"]);

      expect(await controller.submitDouyinRoomInput(null), isNull);
      expect(
        await controller.submitDouyinRoomInput(
          "https://www.douyin.com/user/abc",
        ),
        isNull,
      );
      expect(controller.captured, ["123456"]);
    });

    test('非抖音站点不会走抖音直达导航', () async {
      final controller = _CapturingSearchListController(
        Sites.allSites[Constant.kBiliBili]!,
      );

      expect(await controller.submitDouyinRoomInput("123456"), isNull);
      expect(controller.captured, isEmpty);
    });

    test('解析等待期间 controller 已关闭则不导航', () async {
      final controller = _CapturingSearchListController(
        Sites.allSites[Constant.kDouyin]!,
      );
      const tag = "douyin_closed_entry_test";
      Get.put<SearchListController>(controller, tag: tag);
      Get.delete<SearchListController>(tag: tag);

      expect(await controller.submitDouyinRoomInput("123456"), isNull);
      expect(controller.captured, isEmpty);
    });
  });

  group('ParseController 抖音链接', () {
    test('官方直播长链复用新解析，evil 域和个人主页不误判', () async {
      final controller = ParseController();

      final result = await controller.parse(
        "https://live.douyin.com/123456?from=share",
      );
      expect(result[0], "123456");
      expect(result[1].id, Constant.kDouyin);

      expect(
        await controller.parse(
          "https://evil.example.com/live.douyin.com/123",
        ),
        isEmpty,
      );
      expect(
        await controller.parse("https://www.douyin.com/user/abc"),
        isEmpty,
      );
    });
  });

  group('SearchListView 抖音直达 UI', () {
    testWidgets('非抖音搜索页可构建且无 GetX 异常', (tester) async {
      final controller = _CapturingSearchListController(
        Sites.allSites[Constant.kDouyu]!,
      );
      const tag = "douyu_ui_test";
      Get.put<SearchListController>(controller, tag: tag);
      addTearDown(() => Get.delete<SearchListController>(tag: tag));

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SearchListView(tag))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text("链接/房间号直达"), findsNothing);
    });

    testWidgets('抖音空/错误态按钮可见，取消不导航，数字提交走导航', (tester) async {
      final controller = _CapturingSearchListController(
        Sites.allSites[Constant.kDouyin]!,
      );
      const tag = "douyin_ui_test";
      Get.put<SearchListController>(controller, tag: tag);
      addTearDown(() => Get.delete<SearchListController>(tag: tag));

      controller.pageEmpty.value = true;
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SearchListView(tag))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("链接/房间号直达"), findsOneWidget);

      controller.pageError.value = true;
      await tester.pump();
      expect(find.text("链接/房间号直达"), findsOneWidget);

      await tester.tap(find.text("链接/房间号直达"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text("取消"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.captured, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text("链接/房间号直达"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), "123456");
      await tester.tap(find.text("进入"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.captured, ["123456"]);
      expect(tester.takeException(), isNull);
    });
  });
}
