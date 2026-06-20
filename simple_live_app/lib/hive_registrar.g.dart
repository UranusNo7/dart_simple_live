import 'package:hive_ce/hive.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(FollowUserAdapter());
    registerAdapter(FollowUserTagAdapter());
    registerAdapter(HistoryAdapter());
  }
}
