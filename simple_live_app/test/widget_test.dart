import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  testWidgets('loading widget renders an activity indicator', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: AppLoaddingWidget(),
        ),
      ),
    );

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('SuperChat custom countdown ticks and expires once',
      (tester) async {
    var expireCount = 0;
    final now = DateTime.now();
    final message = LiveSuperChatMessage(
      backgroundBottomColor: '#000000',
      backgroundColor: '#ffffff',
      endTime: now.add(const Duration(seconds: 30)),
      face: '',
      message: 'message',
      price: 10,
      startTime: now,
      userName: 'user',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SuperChatCard(
            message,
            customCountdown: 2,
            onExpire: () => expireCount++,
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    expect(expireCount, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0'), findsOneWidget);
    await tester.pump();
    expect(expireCount, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(expireCount, 1);
  });
}
