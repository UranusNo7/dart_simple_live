import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_app/widgets/page_list_view.dart';

class _FakePageController extends BasePageController<String> {
  @override
  Future<PageData<String>> getPageData(int page, int pageSize) async {
    return const PageData(items: ['alpha', 'beta'], hasMore: false);
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  testWidgets('PageGridView renders items loaded after the first frame',
      (tester) async {
    final controller = _FakePageController();

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: PageGridView(
            pageController: controller,
            crossAxisCount: 2,
            itemBuilder: (_, index) => Text(controller.list[index]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('alpha'), findsNothing);

    await controller.loadData();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.onClose();
  });

  testWidgets('PageListView renders items loaded after the first frame',
      (tester) async {
    final controller = _FakePageController();

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: PageListView(
            pageController: controller,
            itemBuilder: (_, index) => Text(controller.list[index]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('alpha'), findsNothing);

    await controller.loadData();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.onClose();
  });
}
