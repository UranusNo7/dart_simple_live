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
