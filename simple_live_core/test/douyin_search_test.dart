import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

String liveItemRaw(String webRid, String nickname, int online) {
  return json.encode({
    "owner": {"web_rid": webRid, "nickname": nickname},
    "title": "$nickname 的直播间",
    "cover": {
      "url_list": ["https://cover.example.com/$webRid.jpg"],
    },
    "stats": {"total_user": online},
  });
}

Map<String, dynamic> searchResponse({
  required List<dynamic> data,
  Object? hasMore,
}) {
  return {
    "status_code": 0,
    "data": data,
    if (hasMore != null) "has_more": hasMore,
  };
}

void main() {
  group('DouyinSite.buildSearchRoomUri', () {
    test('分页按每页 10 条计算 offset 并保留关键词', () {
      final first = DouyinSite.buildSearchRoomUri("英雄联盟", 1);
      final third = DouyinSite.buildSearchRoomUri("英雄联盟", 3);

      expect(first.queryParameters["offset"], "0");
      expect(third.queryParameters["offset"], "20");
      expect(third.queryParameters["count"], "10");
      expect(third.queryParameters["search_channel"], "aweme_live");
      expect(third.queryParameters["keyword"], "英雄联盟");
    });
  });

  group('DouyinSite.parseSearchRoomResult', () {
    test("登录风控状态码抛出明确的登录提示，而不是静默返回空列表", () {
      expect(
        () => DouyinSite.parseSearchRoomResult({
          "status_code": 2483,
          "status_msg": "请先登录，再继续搜索吧",
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("登录"),
          ),
        ),
      );
    });

    test("其他状态码抛出包含状态码的失败信息", () {
      expect(
        () => DouyinSite.parseSearchRoomResult({"status_code": 10011}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("10011"),
          ),
        ),
      );
    });

    test("解析直播间 rawdata 并保留分页标记", () {
      final result = DouyinSite.parseSearchRoomResult(
        searchResponse(
          data: [
            {
              "lives": {"rawdata": liveItemRaw("123456789", "主播A", 1234)},
            },
          ],
          hasMore: 1,
        ),
      );

      expect(result.hasMore, isTrue);
      expect(result.items, hasLength(1));
      expect(result.items.first.roomId, "123456789");
      expect(result.items.first.userName, "主播A");
      expect(result.items.first.title, "主播A 的直播间");
      expect(result.items.first.cover, "https://cover.example.com/123456789.jpg");
      expect(result.items.first.online, 1234);
    });

    test("has_more 为 0 时不因返回 10 条而误判还有下一页", () {
      final data = List.generate(
        10,
        (i) => {
          "lives": {"rawdata": liveItemRaw("$i", "主播$i", i)},
        },
      );
      final result = DouyinSite.parseSearchRoomResult(
        searchResponse(data: data, hasMore: 0),
      );

      expect(result.items, hasLength(10));
      expect(result.hasMore, isFalse);
    });

    test("响应缺少 has_more 时按返回条数兜底判断", () {
      final data = List.generate(
        10,
        (i) => {
          "lives": {"rawdata": liveItemRaw("$i", "主播$i", i)},
        },
      );
      final result = DouyinSite.parseSearchRoomResult(searchResponse(data: data));

      expect(result.hasMore, isTrue);
    });

    test("跳过缺少 lives/rawdata 或 rawdata 非法的脏数据", () {
      final result = DouyinSite.parseSearchRoomResult(
        searchResponse(
          data: [
            null,
            "bad-item",
            {"lives": null},
            {"lives": {}},
            {"lives": {"rawdata": "not-json"}},
            {"lives": {"rawdata": liveItemRaw("987654321", "主播B", 8)}},
          ],
        ),
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.roomId, "987654321");
      expect(result.items.first.userName, "主播B");
      expect(result.hasMore, isFalse);
    });

    test("owner.web_rid 缺失或为空时不加入结果，避免把 null 当房间号", () {
      String rawWithOwner(Map<String, dynamic> owner) {
        return json.encode({
          "owner": owner,
          "title": "标题",
          "cover": {
            "url_list": ["https://cover.example.com/a.jpg"],
          },
          "stats": {"total_user": 1},
        });
      }

      final result = DouyinSite.parseSearchRoomResult(
        searchResponse(
          data: [
            {
              "lives": {
                "rawdata": rawWithOwner({"nickname": "无号主播"}),
              },
            },
            {
              "lives": {
                "rawdata": rawWithOwner({"web_rid": null, "nickname": "空号主播"}),
              },
            },
            {
              "lives": {
                "rawdata": rawWithOwner({"web_rid": "", "nickname": "空串主播"}),
              },
            },
            {
              "lives": {
                "rawdata": rawWithOwner({"web_rid": "   ", "nickname": "空白主播"}),
              },
            },
            {
              "lives": {
                "rawdata": rawWithOwner({"web_rid": "123456789", "nickname": "正常主播"}),
              },
            },
          ],
        ),
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.roomId, "123456789");
      expect(result.items.first.userName, "正常主播");
    });

    test("空 body 或 blocked 保留“受限制”提示，不降级为格式异常", () {
      for (var body in <dynamic>[null, "", "blocked"]) {
        expect(
          () => DouyinSite.parseSearchRoomResult(body),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              "message",
              contains("限制"),
            ),
          ),
        );
      }
    });

    test("非 Map 响应抛出格式异常", () {
      expect(
        () => DouyinSite.parseSearchRoomResult("not-a-map"),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("格式异常"),
          ),
        ),
      );
    });
  });

  group('DouyinSite.searchRooms 请求', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = HttpClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      HttpClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    _FakeAdapter fakeWith(Map<String, dynamic> body) {
      final adapter = _FakeAdapter(
        (options) => ResponseBody.fromString(
          json.encode(body),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      HttpClient.instance.dio.httpClientAdapter = adapter;
      return adapter;
    }

    test("使用用户 Cookie 并携带 a_bogus/msToken 签名", () async {
      final adapter = fakeWith({
        "status_code": 0,
        "data": [
          {
            "lives": {"rawdata": liveItemRaw("123456789", "主播A", 1)},
          },
        ],
        "has_more": 0,
      });
      final site = DouyinSite();
      site.cookie = "ttwid=user-ttwid; sessionid=user-session";

      final result = await site.searchRooms("英雄联盟");

      expect(result.items, hasLength(1));
      final request = adapter.lastRequest!;
      expect(
        request.headers["cookie"],
        "ttwid=user-ttwid; sessionid=user-session",
      );
      expect(request.uri.query, contains("a_bogus="));
      expect(request.uri.query, contains("msToken="));
      expect(
        request.uri.query,
        contains("keyword=%E8%8B%B1%E9%9B%84%E8%81%94%E7%9B%9F"),
      );
      expect(request.uri.host, "www.douyin.com");
    });

    test("2483 直接抛登录提示，不返回空列表", () async {
      fakeWith({
        "status_code": 2483,
        "status_msg": "请先登录，再继续搜索吧",
      });
      final site = DouyinSite();
      site.cookie = "ttwid=user-ttwid";

      expect(
        site.searchRooms("英雄联盟"),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("登录"),
          ),
        ),
      );
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
