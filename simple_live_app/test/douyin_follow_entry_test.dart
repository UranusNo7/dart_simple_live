import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DBService db;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp("douyin_follow_test_");
    Hive.init(tempDir.path);
    Hive.registerAdapter(FollowUserAdapter());
    Hive.registerAdapter(FollowUserTagAdapter());
    Hive.registerAdapter(HistoryAdapter());
  });

  setUp(() async {
    db = DBService();
    await db.init();
    await db.followBox.clear();
    Get.put<DBService>(db);
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('FollowUser 通过 DBService 写入后重开仍在', () async {
    const id = "douyin_906466692449";
    await db.addFollow(
      FollowUser(
        id: id,
        roomId: "906466692449",
        siteId: Constant.kDouyin,
        userName: "主播A",
        face: "https://avatar.example.com/a.jpg",
        addTime: DateTime(2026, 1, 1),
      ),
    );

    expect(db.getFollowExist(id), isTrue);

    await db.followBox.close();
    final reopened = DBService();
    await reopened.init();
    final loaded = reopened.followBox.get(id);

    expect(loaded, isNotNull);
    expect(loaded!.roomId, "906466692449");
    expect(loaded.siteId, Constant.kDouyin);
    expect(loaded.userName, "主播A");

    await reopened.followBox.close();
  });

  test('LiveRoomController.followUser 使用 canonical roomId 写入关注', () async {
    final site = Sites.allSites[Constant.kDouyin]!;
    final controller = LiveRoomController(
      pSite: site,
      pRoomId: "temporary-room-id",
    );
    // 模拟 loadData 后 core 返回的稳定 webRid 已写回 rxRoomId。
    controller.rxRoomId.value = "906466692449";
    controller.detail.value = LiveRoomDetail(
      roomId: "906466692449",
      title: "直播间标题",
      cover: "",
      userName: "主播A",
      userAvatar: "https://avatar.example.com/a.jpg",
      online: 1,
      status: true,
      url: "https://live.douyin.com/906466692449",
    );

    controller.followUser();
    await pumpEventQueue();

    final saved = db.followBox.get("douyin_906466692449");
    expect(saved, isNotNull);
    expect(saved!.roomId, "906466692449");
    expect(saved.siteId, Constant.kDouyin);
    expect(saved.userName, "主播A");
  });
}
