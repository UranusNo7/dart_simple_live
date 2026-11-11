import 'package:flutter/material.dart';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SearchListView extends StatelessWidget {
  final String tag;
  const SearchListView(this.tag, {Key? key}) : super(key: key);
  SearchListController get controller =>
      Get.find<SearchListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    var roomRowCount = MediaQuery.of(context).size.width ~/ 200;
    if (roomRowCount < 2) roomRowCount = 2;

    var userRowCount = MediaQuery.of(context).size.width ~/ 500;
    if (userRowCount < 1) userRowCount = 1;
    return KeepAliveWrapper(
      child: Column(
        children: [
          if (controller.site.id == Constant.kDouyin)
            Obx(
              () => controller.searchMode.value == 0
                  ? Padding(
                      padding: AppStyle.edgeInsetsA12,
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showRoomInputDialog(context),
                          icon: const Icon(Icons.link),
                          label: const Text("链接/房间号直达"),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          Expanded(
            child: Obx(
              () => controller.searchMode.value == 0
                  ? PageGridView(
                      pageController: controller,
                      padding: AppStyle.edgeInsetsA12,
                      firstRefresh: false,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      crossAxisCount: roomRowCount,
                      showPageLoadding: true,
                      itemBuilder: (_, i) {
                        var item = controller.list[i] as LiveRoomItem;
                        return LiveRoomCard(controller.site, item);
                      },
                    )
                  : PageGridView(
                      crossAxisSpacing: 12,
                      crossAxisCount: userRowCount,
                      pageController: controller,
                      firstRefresh: true,
                      itemBuilder: (_, i) {
                        var item = controller.list[i] as LiveAnchorItem;

                        return ListTile(
                          leading: NetImage(
                            item.avatar,
                            width: 48,
                            height: 48,
                            borderRadius: 24,
                          ),
                          title: Text(item.userName),
                          subtitle: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: item.liveStatus
                                      ? Colors.green
                                      : Colors.grey,
                                  borderRadius: AppStyle.radius12,
                                ),
                              ),
                              AppStyle.hGap4,
                              Text(
                                item.liveStatus ? "直播中" : "未开播",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: item.liveStatus ? null : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            AppNavigator.toLiveRoomDetail(
                                site: controller.site, roomId: item.roomId);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRoomInputDialog(BuildContext context) async {
    var input = "";
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("直达抖音直播间"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "直播间号（不是抖音号）或直播链接/分享短链",
          ),
          onChanged: (value) => input = value,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(input),
            child: const Text("进入"),
          ),
        ],
      ),
    );
    if (submitted == null) {
      return;
    }
    final roomId = await controller.submitDouyinRoomInput(submitted);
    if (roomId == null) {
      SmartDialog.showToast("无法识别抖音直播间链接或房间号");
    }
  }
}
