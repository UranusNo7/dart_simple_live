import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/mine/parse/douyin_room_input.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

class SearchListController extends BasePageController {
  String keyword = "";

  /// 搜索模式，0=直播间，1=主播
  var searchMode = 0.obs;
  final Site site;
  SearchListController(
    this.site,
  );

  @override
  Future refreshData() async {
    if (keyword.isEmpty) {
      return;
    }
    return await super.refreshData();
  }

  @override
  Future<PageData> getPageData(int page, int pageSize) async {
    if (keyword.isEmpty) {
      return const PageData(items: [], hasMore: false);
    }
    if (searchMode.value == 1) {
      // 搜索主播
      var result = await site.liveSite.searchAnchors(keyword, page: page);
      return PageData(items: result.items, hasMore: result.hasMore);
    }
    var result = await site.liveSite.searchRooms(keyword, page: page);

    return PageData(items: result.items, hasMore: result.hasMore);
  }

  void clear() {
    pageEmpty.value = false;
    list.clear();
  }

  /// 抖音链接/房间号直达，成功返回解析出的直播间 ID。
  Future<String?> submitDouyinRoomInput(String? input) async {
    if (site.id != Constant.kDouyin || input == null) {
      return null;
    }
    final roomId = await DouyinRoomInput.resolveRoomId(input);
    if (roomId == null || isClosed) {
      return null;
    }
    navigateToRoom(roomId);
    return roomId;
  }

  void navigateToRoom(String roomId) {
    AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
  }
}
