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
  static const int kTrimTriggerThreshold = 50;

  Future addOrUpdateHistory(History history) async {
    await historyBox.put(history.id, history);
    if (historyBox.length > kMaxHistoryCount + kTrimTriggerThreshold) {
      _trimHistory();
    }
  }

  void _trimHistory() {
    final all = historyBox.values.toList();
    all.sort((a, b) => a.updateTime.compareTo(b.updateTime));
    final toRemove = all.take(all.length - kMaxHistoryCount);
    final ids = toRemove.map((e) => e.id).toList();
    historyBox.deleteAll(ids);
  }

  List<History> getHistores({int? limit}) {
    var his = historyBox.values.toList();
    his.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    if (limit != null && his.length > limit) {
      his = his.sublist(0, limit);
    }
    return his;
  }
}
