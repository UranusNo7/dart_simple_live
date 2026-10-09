import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/mine/mine_page.dart';
import 'package:simple_live_app/routes/route_path.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  test('primary navigation keeps only the three supported destinations', () {
    expect(
      Constant.allHomePages.keys,
      orderedEquals(['recommend', 'follow', 'user']),
    );
    expect(Constant.allHomePages['user']!.index, 2);
  });

  testWidgets('mine page opens the other settings entry', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: [
          GetPage(
            name: '/',
            page: () => const Scaffold(body: MinePage()),
          ),
          GetPage(
            name: RoutePath.kSettingsOther,
            page: () => const Scaffold(
              body: Center(child: Text('其他设置页面')),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.widgetWithText(ListTile, '其他设置');
    expect(entry, findsOneWidget);
    expect(
      find.descendant(
        of: entry,
        matching: find.byIcon(Remix.settings_3_line),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('其他设置页面'), findsOneWidget);
  });
}
