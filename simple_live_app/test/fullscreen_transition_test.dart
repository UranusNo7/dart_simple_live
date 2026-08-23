import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';

void main() {
  test('mobile fullscreen activates its layout before requesting landscape',
      () async {
    final events = <String>[];

    await enterMobileFullScreen(
      hideSystemUi: () async => events.add('hide-system-ui'),
      activateFullScreenLayout: () => events.add('activate-layout'),
      requestLandscape: () async => events.add('request-landscape'),
      rotateToLandscape: true,
    );

    expect(
      events,
      orderedEquals([
        'hide-system-ui',
        'activate-layout',
        'request-landscape',
      ]),
    );
  });
}
