import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class HomeListController extends BasePageController<LiveRoomItem> {
  final Site site;
  HomeListController(this.site);

  @override
  Future<PageData<LiveRoomItem>> getPageData(int page, int pageSize) async {
    var result = await site.liveSite.getRecommendRooms(page: page);

    return PageData(items: result.items, hasMore: result.hasMore);
  }
}
