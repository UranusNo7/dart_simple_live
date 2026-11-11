import 'package:dio/dio.dart';

/// 抖音直播间链接/房间号解析。
///
/// 只接受官方直播域、分享短链和纯数字房间号，不做任意 URL 请求。
class DouyinRoomInput {
  static const Set<String> officialHosts = {
    "live.douyin.com",
    "webcast.amemv.com",
    "v.douyin.com",
  };

  static const int maxRedirects = 5;

  static final RegExp _urlPattern =
      RegExp(r'https?://[^\s]+', caseSensitive: false);
  static final RegExp _digitsPattern = RegExp(r'^\d+$');
  static final RegExp _livePathPattern = RegExp(r'^/(\d+)/?$');
  static final RegExp _webcastPathPattern =
      RegExp(r'^/webcast/reflow/(\d+)/?$');
  static final RegExp _trailingPunctuation =
      RegExp(r'[，。！？；、,.!?;)\]}>]+$');

  /// 从输入中解析出直播间 ID；失败返回 null。
  ///
  /// [followRedirect] 仅用于测试注入，默认用 Dio 读取短链 Location。
  static Future<String?> resolveRoomId(
    String input, {
    Future<String?> Function(String url)? followRedirect,
  }) async {
    final text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    if (_digitsPattern.hasMatch(text)) {
      return text;
    }
    final uri = extractUri(text);
    if (uri == null) {
      return null;
    }
    try {
      return await _resolveUri(
        uri,
        followRedirect ?? _fetchLocation,
        0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 从分享文案中提取第一个 http(s) 链接。
  static Uri? extractUri(String input) {
    final match = _urlPattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    final raw = match.group(0)!.replaceFirst(_trailingPunctuation, "");
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != "http" && uri.scheme != "https") ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static bool isOfficialHost(String host) {
    return officialHosts.contains(host.toLowerCase());
  }

  static bool isRedirectStatus(int? status) {
    return status != null && status >= 300 && status < 400;
  }

  static Future<String?> _resolveUri(
    Uri uri,
    Future<String?> Function(String url) followRedirect,
    int depth,
  ) async {
    if (uri.scheme != "http" && uri.scheme != "https") {
      return null;
    }
    if (!isOfficialHost(uri.host)) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host == "live.douyin.com") {
      return _livePathPattern.firstMatch(uri.path)?.group(1);
    }
    if (host == "webcast.amemv.com") {
      return _webcastPathPattern.firstMatch(uri.path)?.group(1);
    }
    if (host == "v.douyin.com") {
      if (uri.pathSegments.isEmpty || uri.pathSegments.first.isEmpty) {
        return null;
      }
      if (depth >= maxRedirects) {
        return null;
      }
      final location = await followRedirect(uri.toString());
      if (location == null || location.trim().isEmpty) {
        return null;
      }
      final next = uri.resolve(location.trim());
      if (!isOfficialHost(next.host)) {
        return null;
      }
      return _resolveUri(next, followRedirect, depth + 1);
    }
    return null;
  }

  static Future<String?> _fetchLocation(String url) async {
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    ).get<String>(
      url,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final status = response.statusCode;
    if (!isRedirectStatus(status)) {
      return null;
    }
    final location = response.headers.value("location");
    if (location == null || location.trim().isEmpty) {
      return null;
    }
    return location;
  }
}
