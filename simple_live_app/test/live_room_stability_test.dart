import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

void main() {
  test('a newer room request invalidates an older request', () {
    final gate = LiveRoomRequestGate();

    final firstRequest = gate.begin();
    final secondRequest = gate.begin();

    expect(gate.isCurrent(firstRequest), isFalse);
    expect(gate.isCurrent(secondRequest), isTrue);
  });

  test('closing the room invalidates outstanding requests', () {
    final gate = LiveRoomRequestGate();
    final request = gate.begin();

    gate.close();

    expect(gate.isCurrent(request), isFalse);
  });

  test('offline state requires an explicit live-status result', () {
    expect(
      shouldMarkLiveOffline(
        isBackground: true,
        error: null,
        confirmedLiveStatus: false,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: false,
      ),
      isTrue,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: true,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: null,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: 'connection lost',
        confirmedLiveStatus: false,
      ),
      isFalse,
    );
  });

  test('live-status recovery is checked only once per playback cycle', () {
    expect(
      shouldCheckLiveStatus(
        isBackground: false,
        error: null,
        recoveryAttempted: false,
      ),
      isTrue,
    );
    expect(
      shouldCheckLiveStatus(
        isBackground: false,
        error: null,
        recoveryAttempted: true,
      ),
      isFalse,
    );
    expect(
      shouldCheckLiveStatus(
        isBackground: true,
        error: null,
        recoveryAttempted: false,
      ),
      isFalse,
    );
  });

  test('Android phones keep the single-column room layout in landscape', () {
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: true, width: 1200),
      isFalse,
    );
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: false, width: 899),
      isFalse,
    );
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: false, width: 900),
      isTrue,
    );
  });
}
