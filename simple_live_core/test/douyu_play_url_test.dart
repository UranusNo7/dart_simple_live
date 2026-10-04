import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('DouyuSite.parsePlayUrl', () {
    test('拼接正常返回的播放地址并做 html 反转义', () {
      final url = DouyuSite.parsePlayUrl({
        'error': 0,
        'data': {
          'rtmp_url': 'https://dysc1.example.com',
          'rtmp_live': 'live/1234abc.m3u8?a=1&amp;b=2',
        },
      });

      expect(url, 'https://dysc1.example.com/live/1234abc.m3u8?a=1&b=2');
    });

    test('error 不为 0 时返回空字符串', () {
      final url = DouyuSite.parsePlayUrl({
        'error': 1001,
        'error_msg': 'sign expired',
        'data': null,
      });

      expect(url, '');
    });

    test('data 缺失或为 null 时返回空字符串', () {
      expect(DouyuSite.parsePlayUrl({'error': 0}), '');
      expect(DouyuSite.parsePlayUrl({'error': 0, 'data': null}), '');
      expect(DouyuSite.parsePlayUrl(null), '');
    });

    test('rtmp_url 为空时返回空字符串', () {
      final url = DouyuSite.parsePlayUrl({
        'error': 0,
        'data': {'rtmp_url': '', 'rtmp_live': 'live/1234.m3u8'},
      });

      expect(url, '');
    });

    test('rtmp_live 为空时返回空字符串', () {
      final url = DouyuSite.parsePlayUrl({
        'error': 0,
        'data': {'rtmp_url': 'https://dysc1.example.com', 'rtmp_live': ''},
      });

      expect(url, '');
    });

    test('接口报错时不再拼出 "/" 这种垃圾地址', () {
      final response = <String, dynamic>{
        'error': 1001,
        'data': <String, dynamic>{'rtmp_url': '', 'rtmp_live': ''},
      };
      // 修复前的行为：直接字符串插值，得到非空的 "/" ，会被 isNotEmpty 过滤逻辑放行
      final legacy = '${response['data']['rtmp_url']}/'
          '${response['data']['rtmp_live']}';
      expect(legacy, '/');

      expect(DouyuSite.parsePlayUrl(response), '');
    });
  });

  group('DouyuSite.isValidPlayUrl', () {
    test('拒绝无效地址', () {
      expect(DouyuSite.isValidPlayUrl(''), isFalse);
      expect(DouyuSite.isValidPlayUrl('/'), isFalse);
      expect(DouyuSite.isValidPlayUrl('null/live/1234.m3u8'), isFalse);
    });

    test('接受正常地址', () {
      expect(
        DouyuSite.isValidPlayUrl('https://dysc1.example.com/live/1234.m3u8'),
        isTrue,
      );
      expect(
        DouyuSite.isValidPlayUrl('rtmp://dysc1.example.com/live/1234'),
        isTrue,
      );
    });

    test('配合 parsePlayUrl 过滤整批失败结果', () {
      const errors = ['', '/', 'null/x'];
      final urls = errors.map(DouyuSite.isValidPlayUrl).toList();

      expect(urls, [isFalse, isFalse, isFalse]);
    });
  });
}
