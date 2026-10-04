import 'dart:convert';

import 'package:simple_live_core/src/huya_site.dart';
import 'package:test/test.dart';

HuyaLineModel _line({
  String line = "http://al.flv.huya.com/src",
  String stream = "294636272-294636272-1265453152455360512-589396000-10057-A-0-1-imgplus",
  int presenterUid = 294636272,
}) {
  return HuyaLineModel(
    line: line,
    lineType: HuyaLineType.flv,
    flvAntiCode: "",
    hlsAntiCode: "",
    streamName: stream,
    cdnType: "AL",
    presenterUid: presenterUid,
  );
}

// 真实 WUP getCdnTokenInfoEx 返回体样例（ctype=huya_pc_exe，不含 t 字段）
final _fmPlain = base64.encode(utf8.encode("D8x8bcJ3h6DFJ4pQTY_0_1_2_3="));

String _token() {
  return "wsSecret=e9af9e3b7714bb701725167f38365725"
      "&wsTime=6ac27eb6"
      "&fm=${Uri.encodeComponent(_fmPlain)}"
      "&ctype=huya_pc_exe"
      "&fs=gctex";
}

Map<String, String> _parse(String antiCode) {
  return Uri(query: antiCode).queryParametersAll.map(
      (k, v) => MapEntry(k, v.first));
}

void main() {
  final site = HuyaSite();

  group("buildAntiCode 签名", () {
    test("令牌缺少 t 字段时按 ctype 推导 PC 平台 id，不再输出 t=0", () {
      final res = _parse(site.buildAntiCode("stream", 100, _token()));
      expect(Uri(query: _token()).queryParametersAll.containsKey("t"), isFalse,
          reason: "样例令牌本身不含 t 参数");
      expect(res["t"], "100");
    });

    test("huya_com 推导为 WAP 103 并改用 uid/uuid 字段", () {
      final res = _parse(site.buildAntiCode(
          "stream", 100, _token().replaceAll("huya_pc_exe", "huya_com")));
      expect(res["t"], "103");
      expect(res.containsKey("uid"), isTrue);
      expect(res.containsKey("u"), isFalse);
    });

    test("服务端显式返回 t 时以服务端为准", () {
      final res =
          _parse(site.buildAntiCode("stream", 100, "${_token()}&t=100"));
      expect(res["t"], "100");
    });

    test("重签后 wsSecret 被替换，wsTime/fm/ctype/fs 保留", () {
      final token = _token();
      final res = _parse(site.buildAntiCode("stream", 100, token));
      expect(res["wsSecret"], isNot("e9af9e3b7714bb701725167f38365725"));
      expect(res["wsTime"], "6ac27eb6");
      expect(res["ctype"], "huya_pc_exe");
      expect(res["fs"], "gctex");
      expect(res["fm"], Uri.encodeComponent(_fmPlain));
      expect(res.containsKey("u"), isTrue, reason: "PC 分支使用 rotl64 后的 uid");
    });

    test("缺少签名必需字段时原样返回，不抛异常", () {
      for (final broken in [
        "wsSecret=abc&wsTime=6ac27eb6&ctype=huya_pc_exe&fs=gctex", // 无 fm
        "wsSecret=abc&fm=abc&ctype=huya_pc_exe&fs=gctex", // 无 wsTime
        "wsSecret=abc&fm=abc&wsTime=6ac27eb6&ctype=huya_pc_exe", // 无 fs
      ]) {
        expect(site.buildAntiCode("stream", 100, broken), broken);
      }
    });
  });

  group("buildPlayUrl 地址拼装", () {
    test("原画不追加 ratio，线路地址与 streamName 直接拼接", () {
      final line = _line();
      final url = site.buildPlayUrl(line, 0, _token());
      expect(
          url,
          startsWith("${line.line}/${line.streamName}.flv?"));
      expect(url, endsWith("&codec=264"));
      expect(url, isNot(contains("ratio=")));
    });

    test("指定码率时追加 ratio 参数", () {
      final line = _line();
      final url = site.buildPlayUrl(line, 2000, _token());
      expect(url, endsWith("&codec=264&ratio=2000"));
    });

    test("无法重签时仍使用服务端原始令牌拼接", () {
      final url = site.buildPlayUrl(_line(), 0, "wsSecret=abc&fs=gctex");
      expect(url, contains("/src/294636272-294636272"));
      expect(url, contains("wsSecret=abc&fs=gctex&codec=264"));
    });
  });
}