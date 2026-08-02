import 'dart:async';
import 'dart:io';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Douyu reconnects when the danmaku server becomes available',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        if (requestCount <= 2) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {});
      });

      final danmaku = DouyuDanmaku()
        ..serverUrl =
            'ws://${InternetAddress.loopbackIPv4.address}:${server.port}';
      final ready = Completer<void>();
      final initialFailure = Completer<void>();

      addTearDown(() async {
        await danmaku.stop();
        await server.close(force: true);
      });

      danmaku.onReady = ready.complete;
      danmaku.onClose = (_) {
        if (!initialFailure.isCompleted) {
          initialFailure.complete();
        }
      };
      await danmaku.start('test-room');

      await initialFailure.future.timeout(const Duration(seconds: 2));
      await ready.future.timeout(const Duration(seconds: 7));
      expect(requestCount, 3);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'Douyu stops retrying after the danmaku client is stopped',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });

      final danmaku = DouyuDanmaku()
        ..serverUrl =
            'ws://${InternetAddress.loopbackIPv4.address}:${server.port}';
      final initialFailure = Completer<void>();

      addTearDown(() async {
        await danmaku.stop();
        await server.close(force: true);
      });

      danmaku.onClose = (_) {
        if (!initialFailure.isCompleted) {
          initialFailure.complete();
        }
      };
      await danmaku.start('test-room');
      await initialFailure.future.timeout(const Duration(seconds: 2));

      await danmaku.stop();
      await Future<void>.delayed(const Duration(seconds: 6));

      expect(requestCount, 2);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
