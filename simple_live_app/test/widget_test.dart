import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';

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
}
