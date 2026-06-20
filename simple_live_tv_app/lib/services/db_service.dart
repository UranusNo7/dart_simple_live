import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';

import 'package:simple_live_tv_app/models/db/history.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();
  late Box<History> historyBox;
  late Box<FollowUser> followBox;

  Future init() async {
    historyBox = await Hive.openBox("TVHostiry");
    followBox = await Hive.openBox("TVFollowUser");
  }

  bool getFollowExist(String id) {
    return followBox.containsKey(id);
  }

  List<FollowUser> getFollowList() {
    return followBox.values.toList();
  }

  Future addFollow(FollowUser follow) async {
    await followBox.put(follow.id, follow);
  }

  Future deleteFollow(String id) async {
    await followBox.delete(id);
  }

  History? getHistory(String id) {
    if (historyBox.containsKey(id)) {
      return historyBox.get(id);
    }
    return null;
  }

  static const int kMaxHistoryCount = 500;

  Future addOrUpdateHistory(History history) async {
    await historyBox.put(history.id, history);
    _trimHistory();
  }

  void _trimHistory() {
    final count = historyBox.length;
    if (count > kMaxHistoryCount) {
      final all = historyBox.values.toList();
      all.sort((a, b) => a.updateTime.compareTo(b.updateTime));
      final toRemove = all.sublist(0, count - kMaxHistoryCount);
      for (final item in toRemove) {
        historyBox.delete(item.id);
      }
    }
  }

  List<History> getHistores() {
    var his = historyBox.values.toList();
    his.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    return his;
  }
}
