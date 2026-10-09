import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveRoomRequestGate {
  int _generation = 0;
  bool _closed = false;

  int begin() {
    return ++_generation;
  }

  void invalidate() {
    _generation++;
  }

  void close() {
    _closed = true;
    _generation++;
  }

  int get current => _generation;

  bool isCurrent(int generation) {
    return !_closed && generation == _generation;
  }
}

bool shouldMarkLiveOffline({
  required bool isBackground,
  required String? error,
  required bool? confirmedLiveStatus,
}) {
  return !isBackground && error == null && confirmedLiveStatus == false;
}

bool shouldCheckLiveStatus({
  required bool isBackground,
  required String? error,
  required bool recoveryAttempted,
}) {
  return !isBackground && error == null && !recoveryAttempted;
}

/// 播放失败后可以采取的恢复动作。
enum LiveRecoveryAction {
  /// 重新打开当前地址，只适用于地址不会过期的普通站点
  retryCurrentUrl,

  /// 重新获取播放地址
  refreshPlayUrl,

  /// 切换到下一条线路
  switchLine,

  /// 线路已用尽，先确认真实直播状态
  confirmLiveStatus,

  /// 本轮已无可用动作
  giveUp,
}

/// 直播播放恢复决策：保存重试预算、判定本轮播放进展、决定失败后的下一步动作。
///
/// 斗鱼地址带 `expire=300`，本次日志中连接约每 300 秒被重置一次，与 `expire` 一致，
/// 但现有证据无法确定是哪一跳断开。地址不可用后重试旧地址没有意义，因此
/// [refreshUrlsOnFailure] 的站点失败后直接刷新地址。刷新预算只在本轮播放位置
/// 前进达到 [minProgressToRestore] 后归还，不会因为 open/playing 事件归还，
/// 避免地址一直不可用时形成快速重连循环。
class LivePlaybackRecovery {
  LivePlaybackRecovery({required this.refreshUrlsOnFailure});

  final bool refreshUrlsOnFailure;

  /// 普通站点允许的同一地址重试次数
  static const int maxSameUrlRetries = 2;

  /// 每轮允许重新获取播放地址的次数
  static const int maxUrlRefreshes = 1;

  /// 本轮播放位置需要前进的时长才归还预算。
  /// 这是同一轮内的位置增量，不代表连续的播放时长。
  static const Duration minProgressToRestore = Duration(seconds: 5);

  int sameUrlRetries = 0;
  int urlRefreshes = 0;

  /// 线路用尽后是否已经确认过真实直播状态
  bool liveStatusChecked = false;

  /// 后台期间播放已丢失（失败或 EOF），回到前台需要重新拉流
  bool lostWhileBackgrounded = false;

  /// 回前台停滞探测是否进行中，避免连续 resumed 反复重连
  bool resumeProbeRunning = false;

  /// 本轮播放的进展基准，null 表示还没有收到本轮的位置事件
  Duration? _sessionStart;
  Duration _lastPosition = Duration.zero;

  /// 每次开始新的播放请求时调用，上一轮的位置不能用于归还本轮预算
  void armNewPlaybackSession() {
    _sessionStart = null;
  }

  /// 已取回新的播放地址，重新开始同一地址的重试计数
  void startNewAddressCycle() {
    sameUrlRetries = 0;
  }

  /// 切换清晰度等全新播放周期，同时归还刷新预算与状态确认机会
  void startNewQualityCycle() {
    startNewAddressCycle();
    urlRefreshes = 0;
    liveStatusChecked = false;
  }

  /// 记录一次播放失败，后台丢失要在回到前台时恢复
  void markFailure({required bool isBackground}) {
    if (isBackground) {
      lostWhileBackgrounded = true;
    }
  }

  /// 播放位置在本轮内前进达到阈值才代表真的在播放，返回是否归还了已用完的预算。
  ///
  /// [armNewPlaybackSession] 之后的第一个位置事件只作为本轮基准；位置回退
  /// （新的一轮从 0 开始）也重新取基准，因此旧请求遗留的位置事件不会瞬间归还预算。
  bool onPlaybackProgress(Duration position) {
    final sessionStart = _sessionStart;
    if (sessionStart == null || position < _lastPosition) {
      _sessionStart = position;
      _lastPosition = position;
      return false;
    }
    if (position <= _lastPosition) {
      _lastPosition = position;
      return false;
    }
    _lastPosition = position;
    if (position - sessionStart < minProgressToRestore) {
      return false;
    }
    final restored =
        urlRefreshes > 0 || liveStatusChecked || lostWhileBackgrounded;
    urlRefreshes = 0;
    liveStatusChecked = false;
    lostWhileBackgrounded = false;
    return restored;
  }

  /// 决定这次失败下一步做什么，并消耗对应的预算
  LiveRecoveryAction planFailure({
    required bool hasMoreLines,
    required bool isBackground,
    required String? error,
  }) {
    if (!refreshUrlsOnFailure && sameUrlRetries < maxSameUrlRetries) {
      sameUrlRetries += 1;
      return LiveRecoveryAction.retryCurrentUrl;
    }
    if (urlRefreshes < maxUrlRefreshes) {
      urlRefreshes += 1;
      sameUrlRetries = 0;
      return LiveRecoveryAction.refreshPlayUrl;
    }
    if (hasMoreLines) {
      return LiveRecoveryAction.switchLine;
    }
    if (shouldCheckLiveStatus(
      isBackground: isBackground,
      error: error,
      recoveryAttempted: liveStatusChecked,
    )) {
      liveStatusChecked = true;
      return LiveRecoveryAction.confirmLiveStatus;
    }
    return LiveRecoveryAction.giveUp;
  }

  bool beginResumeProbe() {
    if (resumeProbeRunning) {
      return false;
    }
    resumeProbeRunning = true;
    return true;
  }

  void endResumeProbe() {
    resumeProbeRunning = false;
  }

  /// 探测窗口内播放位置没有前进即为静默停滞；[playing] 为假表示播放器处于暂停状态，不打扰
  bool shouldRecoverOnStall({
    required bool positionAdvanced,
    required bool playing,
  }) {
    return playing && !positionAdvanced;
  }
}

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
  static const int kMaxMessagesSoftLimit = 200;
  static const int kMaxMessagesHardLimit = 1000;

  final Site pSite;
  final String pRoomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    recovery = LivePlaybackRecovery(
      refreshUrlsOnFailure: site.id == Constant.kDouyu,
    );
    liveDanmaku = site.liveSite.getDanmaku();
    // 抖音应该默认是竖屏的
    if (site.id == "douyin") {
      isVertical.value = true;
    }
  }

  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();

  /// 滚动控制
  final ScrollController scrollController = ScrollController();

  /// 是否已调度滚动到底部（避免重复注册 addPostFrameCallback）
  bool _scrollScheduled = false;

  /// 聊天信息
  RxList<LiveMessage> messages = RxList<LiveMessage>();

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;

  /// 设置的自动关闭时间（分钟）
  var autoExitMinutes = 60.obs;

  ///是否延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  /// 是否禁用自动滚动聊天栏
  /// - 当用户向上滚动聊天栏时，不再自动滚动
  var disableAutoScroll = false.obs;

  /// 是否处于后台
  var isBackground = false;

  /// 直播间加载失败
  var loadError = false.obs;
  Error? error;

  // 开播时长状态变量
  var liveDuration = "00:00:00".obs;
  Timer? _liveDurationTimer;

  final LiveRoomRequestGate _roomRequestGate = LiveRoomRequestGate();
  final LiveRoomRequestGate _playbackRequestGate = LiveRoomRequestGate();
  Future<void> _playerOperation = Future<void>.value();
  int? _activePlaybackRequest;
  bool _mediaRecoveryInProgress = false;
  late final LivePlaybackRecovery recovery;
  bool _closed = false;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    if (FollowService.instance.followList.isEmpty) {
      FollowService.instance.loadData();
    }
    initAutoExit();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    unawaited(loadData());

    scrollController.addListener(scrollListener);
    _positionSubscription = player.stream.position.listen(_onPlaybackPosition);

    super.onInit();
  }

  StreamSubscription<Duration>? _positionSubscription;

  /// 只有当前播放请求仍在进行、且没有正在恢复时才统计进展，
  /// 旧请求遗留或恢复过程中的位置事件不参与预算归还
  void _onPlaybackPosition(Duration position) {
    if (_activePlaybackRequest == null || _mediaRecoveryInProgress) {
      return;
    }
    if (recovery.onPlaybackProgress(position)) {
      Log.d("本轮播放位置已前进，恢复重试预算");
    }
  }

  void scrollListener() {
    if (scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      disableAutoScroll.value = true;
    }
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (AppSettingsController.instance.autoExitEnable.value) {
      autoExitEnable.value = true;
      autoExitMinutes.value =
          AppSettingsController.instance.autoExitDuration.value;
      setAutoExit();
    } else {
      autoExitMinutes.value =
          AppSettingsController.instance.roomAutoExitDuration.value;
    }
  }

  void setAutoExit() {
    if (!autoExitEnable.value) {
      autoExitTimer?.cancel();
      return;
    }
    autoExitTimer?.cancel();
    countdown.value = autoExitMinutes.value * 60;
    autoExitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      countdown.value -= 1;
      if (countdown.value <= 0) {
        timer = Timer(const Duration(seconds: 10), () async {
          await WakelockPlus.disable();
          exit(0);
        });
        autoExitTimer?.cancel();
        var delay = await Utils.showAlertDialog("定时关闭已到时,是否延迟关闭?",
            title: "延迟关闭", confirm: "延迟", cancel: "关闭", selectable: true);
        if (delay) {
          timer.cancel();
          delayAutoExit.value = true;
          showAutoExitSheet();
          setAutoExit();
        } else {
          delayAutoExit.value = false;
          await WakelockPlus.disable();
          exit(0);
        }
      }
    });
  }
  // 弹窗逻辑

  Future<void> refreshRoom() async {
    //messages.clear();
    _roomRequestGate.invalidate();
    superChats.clear();
    liveDanmaku.stop();

    await _stopPlayer();
    if (!_closed) {
      await loadData();
    }
  }

  /// 聊天栏始终滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      // 如果手动上拉过，就不自动滚动到底部
      if (disableAutoScroll.value) {
        return;
      }
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// 初始化弹幕接收事件
  void initDanmau(int roomRequest) {
    liveDanmaku.onMessage = (msg) {
      if (_roomRequestGate.isCurrent(roomRequest)) {
        onWSMessage(msg);
      }
    };
    liveDanmaku.onClose = (msg) {
      if (_roomRequestGate.isCurrent(roomRequest)) {
        onWSClose(msg);
      }
    };
    liveDanmaku.onReady = () {
      if (_roomRequestGate.isCurrent(roomRequest)) {
        onWSReady();
      }
    };
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) {
    if (msg.type == LiveMessageType.chat) {
      if (messages.length > kMaxMessagesHardLimit) {
        messages.removeRange(0, messages.length - kMaxMessagesSoftLimit);
      }

      // 关键词屏蔽检查
      for (var pattern in AppSettingsController.instance.shieldPatterns) {
        if (msg.message.contains(pattern)) {
          return;
        }
      }

      messages.add(msg);

      if (!_scrollScheduled) {
        _scrollScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollScheduled = false;
          chatScrollToBottom();
        });
      }
      if (!liveStatus.value || isBackground) {
        return;
      }

      addDanmaku(
        DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(
            255,
            msg.color.r,
            msg.color.g,
            msg.color.b,
          ),
        ),
      );
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      superChats.add(msg.data);
    }
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    messages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 接收到WebSocket关闭信息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket准备就绪
  void onWSReady() {
    addSysMsg("弹幕服务器连接正常");
  }

  /// 加载直播间信息
  Future<void> loadData() async {
    if (_closed) {
      return;
    }

    final roomRequest = _roomRequestGate.begin();
    final playbackRequest = _beginPlaybackRequest();
    final requestSite = site;
    final requestRoomId = roomId;

    try {
      SmartDialog.showLoading(msg: "");
      loadError.value = false;
      error = null;
      update();
      addSysMsg("正在读取直播间信息");
      final roomDetail =
          await requestSite.liveSite.getRoomDetail(roomId: requestRoomId);
      if (!_isCurrentRoomRequest(roomRequest)) {
        return;
      }
      detail.value = roomDetail;

      var effectiveRoomId = requestRoomId;
      if (requestSite.id == Constant.kDouyin) {
        // 1.6.0之前收藏的WebRid
        // 1.6.0收藏的RoomID
        // 1.6.0之后改回WebRid
        if (roomDetail.roomId != requestRoomId) {
          final oldId = requestRoomId;
          effectiveRoomId = roomDetail.roomId;
          rxRoomId.value = effectiveRoomId;
          if (followed.value) {
            // 更新关注列表
            DBService.instance.deleteFollow("${requestSite.id}_$oldId");
            DBService.instance.addFollow(
              FollowUser(
                id: "${requestSite.id}_$effectiveRoomId",
                roomId: effectiveRoomId,
                siteId: requestSite.id,
                userName: roomDetail.userName,
                face: roomDetail.userAvatar,
                addTime: DateTime.now(),
              ),
            );
          } else {
            followed.value = DBService.instance
                .getFollowExist("${requestSite.id}_$effectiveRoomId");
          }
        }
      }

      if (!_isCurrentRoomRequest(roomRequest)) {
        return;
      }

      unawaited(
        _getSuperChatMessage(
          roomRequest: roomRequest,
          requestSite: requestSite,
          roomDetail: roomDetail,
        ),
      );

      addHistory(
        roomDetail: roomDetail,
        requestSite: requestSite,
        roomId: effectiveRoomId,
      );
      // 确认房间关注状态
      followed.value = DBService.instance
          .getFollowExist("${requestSite.id}_$effectiveRoomId");
      online.value = roomDetail.online;
      liveStatus.value = roomDetail.status || roomDetail.isRecord;
      if (roomDetail.isRecord) {
        addSysMsg("当前主播未开播，正在轮播录像");
      }
      addSysMsg("开始连接弹幕服务器");
      initDanmau(roomRequest);
      liveDanmaku.start(roomDetail.danmakuData);
      startLiveDurationTimer(); // 启动开播时长定时器

      if (liveStatus.value) {
        await _loadPlayQualities(
          roomRequest: roomRequest,
          playbackRequest: playbackRequest,
          requestSite: requestSite,
          roomDetail: roomDetail,
        );
      }
    } catch (e) {
      if (!_isCurrentRoomRequest(roomRequest)) {
        return;
      }
      Log.logPrint(e);
      //SmartDialog.showToast(e.toString());
      loadError.value = true;
      error = e is Error ? e : null;
    } finally {
      if (_isCurrentRoomRequest(roomRequest)) {
        SmartDialog.dismiss(status: SmartStatus.loading);
      }
    }
  }

  /// 初始化播放器
  Future<void> getPlayQualites() async {
    final roomDetail = detail.value;
    if (roomDetail == null) {
      return;
    }
    final playbackRequest = _beginPlaybackRequest();
    await _loadPlayQualities(
      roomRequest: _roomRequestGate.current,
      playbackRequest: playbackRequest,
      requestSite: site,
      roomDetail: roomDetail,
    );
  }

  Future<void> _loadPlayQualities({
    required int roomRequest,
    required int playbackRequest,
    required Site requestSite,
    required LiveRoomDetail roomDetail,
  }) async {
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }
    qualites.clear();
    currentQuality = -1;
    recovery.startNewQualityCycle();

    try {
      final playQualites =
          await requestSite.liveSite.getPlayQualites(detail: roomDetail);

      if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        return;
      }

      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取播放清晰度");
        return;
      }
      qualites.value = playQualites;
      var qualityLevel = await getQualityLevel();
      if (qualityLevel == 2) {
        //最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else {
        //中间值
        final middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }

      await _loadPlayUrl(
        roomRequest: roomRequest,
        playbackRequest: playbackRequest,
        requestSite: requestSite,
        roomDetail: roomDetail,
        quality: playQualites[currentQuality],
      );
    } catch (e) {
      if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        return;
      }
      Log.logPrint(e);
      SmartDialog.showToast("无法读取播放清晰度");
    }
  }

  Future<int> getQualityLevel() async {
    var qualityLevel = AppSettingsController.instance.qualityLevel.value;
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.first == ConnectivityResult.mobile) {
        qualityLevel =
            AppSettingsController.instance.qualityLevelCellular.value;
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return qualityLevel;
  }

  void getPlayUrl() {
    recovery.startNewQualityCycle();
    unawaited(_reloadPlayUrl());
  }

  Future<void> _reloadPlayUrl() async {
    final roomDetail = detail.value;
    final qualityIndex = currentQuality;
    if (roomDetail == null ||
        qualityIndex < 0 ||
        qualityIndex >= qualites.length) {
      return;
    }

    final playbackRequest = _beginPlaybackRequest();
    await _loadPlayUrl(
      roomRequest: _roomRequestGate.current,
      playbackRequest: playbackRequest,
      requestSite: site,
      roomDetail: roomDetail,
      quality: qualites[qualityIndex],
    );
  }

  Future<void> _loadPlayUrl({
    required int roomRequest,
    required int playbackRequest,
    required Site requestSite,
    required LiveRoomDetail roomDetail,
    required LivePlayQuality quality,
  }) async {
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }

    playUrls.clear();
    currentQualityInfo.value = quality.quality;
    currentLineInfo.value = "";
    currentLineIndex = -1;
    final playUrl = await requestSite.liveSite
        .getPlayUrls(detail: roomDetail, quality: quality);
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.value = playUrl.urls;
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    recovery.startNewAddressCycle();
    await _initPlaylist(
      roomRequest: roomRequest,
      playbackRequest: playbackRequest,
    );
  }

  void changePlayLine(int index) {
    if (index < 0 || index >= playUrls.length) {
      return;
    }
    currentLineIndex = index;
    //重置错误次数
    recovery.startNewAddressCycle();
    final playbackRequest = _beginPlaybackRequest();
    unawaited(
      _setPlayer(
        roomRequest: _roomRequestGate.current,
        playbackRequest: playbackRequest,
        lineIndex: index,
      ),
    );
  }

  Future<void> _initPlaylist({
    required int roomRequest,
    required int playbackRequest,
  }) async {
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    final mediaList =
        playUrls.map((url) => Media(url, httpHeaders: playHeaders)).toList();
    // 斗鱼地址带 expire 且备用 CDN 常不可播，只 open 当前线路，
    // 避免播放器在整张列表里自动打开其它旧地址
    final playable = _openOnlyCurrentLine
        ? Media(playUrls[currentLineIndex], httpHeaders: playHeaders)
        : Playlist(mediaList);

    var opened = false;
    try {
      await _enqueuePlayerOperation(() async {
        if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
          return;
        }
        // 初始化播放器并设置 ao 参数
        await initializePlayer();
        if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
          return;
        }
        await player.open(playable);
        opened = true;
      });
      if (opened && _isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        _activePlaybackRequest = playbackRequest;
        _startNoVideoWatchdog(playbackRequest);
      }
    } catch (e) {
      if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        return;
      }
      Log.logPrint(e);
      errorMsg.value = "播放失败";
    }
  }

  void setPlayer() {
    if (currentLineIndex < 0 || currentLineIndex >= playUrls.length) {
      return;
    }
    final playbackRequest = _beginPlaybackRequest();
    unawaited(
      _setPlayer(
        roomRequest: _roomRequestGate.current,
        playbackRequest: playbackRequest,
        lineIndex: currentLineIndex,
      ),
    );
  }

  /// 斗鱼等地址带有效期的站点只 open 当前线路，其余站点保留多线路播放列表
  bool get _openOnlyCurrentLine => site.id == Constant.kDouyu;

  Future<void> _setPlayer({
    required int roomRequest,
    required int playbackRequest,
    required int lineIndex,
  }) async {
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    var jumped = false;
    try {
      await _enqueuePlayerOperation(() async {
        if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
          return;
        }
        if (_openOnlyCurrentLine) {
          // 斗鱼只 open 当前线路，切线必须重新 open 目标地址；
          // player.jump 只是在旧列表里跳位置，不会重新取流
          await player.open(
            Media(playUrls[lineIndex], httpHeaders: playHeaders),
          );
        } else {
          await player.jump(lineIndex);
        }
        jumped = true;
      });
      if (jumped && _isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        _activePlaybackRequest = playbackRequest;
      }
    } catch (e) {
      if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
        return;
      }
      Log.logPrint(e);
      errorMsg.value = "播放失败";
    }
  }

  @override
  void mediaEnd() {
    super.mediaEnd();
    _handleMediaFailure();
  }

  /// 播放已打开但一直收不到画面的兜底计时器
  Timer? _noVideoTimer;

  @override
  void mediaError(String error) {
    super.mediaError(error);
    _handleMediaFailure(error: error);
  }

  void _handleMediaFailure({String? error}) {
    recovery.markFailure(isBackground: isBackground);
    if (_mediaRecoveryInProgress || _activePlaybackRequest == null) {
      return;
    }
    final roomRequest = _roomRequestGate.current;
    final playbackRequest = _activePlaybackRequest!;
    if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest)) {
      return;
    }
    _mediaRecoveryInProgress = true;
    unawaited(
      _recoverMedia(
        roomRequest: roomRequest,
        playbackRequest: playbackRequest,
        error: error,
      ),
    );
  }

  Future<void> _recoverMedia({
    required int roomRequest,
    required int playbackRequest,
    String? error,
  }) async {
    try {
      var action = recovery.planFailure(
        hasMoreLines: currentLineIndex < playUrls.length - 1,
        isBackground: isBackground,
        error: error,
      );

      if (action == LiveRecoveryAction.retryCurrentUrl) {
        Log.d(
          error == null
              ? "播放结束，尝试第${recovery.sameUrlRetries}次刷新"
              : "播放失败，尝试第${recovery.sameUrlRetries}次刷新",
        );
        if (recovery.sameUrlRetries == 2) {
          //延迟一秒再刷新
          await Future.delayed(const Duration(seconds: 1));
        }
        if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest) ||
            _activePlaybackRequest != playbackRequest) {
          return;
        }
        final nextPlaybackRequest = _beginPlaybackRequest();
        await _setPlayer(
          roomRequest: roomRequest,
          playbackRequest: nextPlaybackRequest,
          lineIndex: currentLineIndex,
        );
        return;
      }

      // 播放地址过期后重试旧地址没有意义，直接重新获取；斗鱼失败后即走这里
      if (action == LiveRecoveryAction.refreshPlayUrl) {
        if (_isCurrentPlaybackRequest(roomRequest, playbackRequest) &&
            _activePlaybackRequest == playbackRequest &&
            playUrls.isNotEmpty &&
            currentQuality >= 0 &&
            currentQuality < qualites.length) {
          Log.d("播放失败，重新获取播放地址");
          await _reloadPlayUrl();
          return;
        }
        // 前置条件不满足时退回到线路切换/状态确认
        action = currentLineIndex < playUrls.length - 1
            ? LiveRecoveryAction.switchLine
            : LiveRecoveryAction.giveUp;
      }

      if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest) ||
          _activePlaybackRequest != playbackRequest ||
          playUrls.isEmpty ||
          currentLineIndex < 0 ||
          currentLineIndex >= playUrls.length) {
        return;
      }

      if (action == LiveRecoveryAction.switchLine) {
        final nextLineIndex = currentLineIndex + 1;
        currentLineIndex = nextLineIndex;
        recovery.startNewAddressCycle();
        final nextPlaybackRequest = _beginPlaybackRequest();
        await _setPlayer(
          roomRequest: roomRequest,
          playbackRequest: nextPlaybackRequest,
          lineIndex: nextLineIndex,
        );
        return;
      }

      bool? confirmedLiveStatus;
      if (action == LiveRecoveryAction.confirmLiveStatus) {
        final roomDetail = detail.value;
        final requestSite = site;
        if (roomDetail != null &&
            _isCurrentPlaybackRequest(roomRequest, playbackRequest) &&
            _activePlaybackRequest == playbackRequest) {
          try {
            confirmedLiveStatus = await requestSite.liveSite
                .getLiveStatus(roomId: roomDetail.roomId);
          } catch (e) {
            Log.logPrint(e);
          }
          if (!_isCurrentPlaybackRequest(roomRequest, playbackRequest) ||
              _activePlaybackRequest != playbackRequest) {
            return;
          }
          if (confirmedLiveStatus == true) {
            Log.d("直播仍在播，重新获取播放地址");
            await _reloadPlayUrl();
            return;
          }
        }
      }

      _activePlaybackRequest = null;
      if (shouldMarkLiveOffline(
        isBackground: isBackground,
        error: error,
        confirmedLiveStatus: confirmedLiveStatus,
      )) {
        liveStatus.value = false;
      } else if (error != null) {
        errorMsg.value = "播放失败";
        SmartDialog.showToast("播放失败:$error");
      }
    } finally {
      _mediaRecoveryInProgress = false;
    }
  }

  int _beginPlaybackRequest() {
    _noVideoTimer?.cancel();
    // 每次开始新的播放请求都重置进展基准，上一轮的位置事件不能归还本轮预算
    recovery.armNewPlaybackSession();
    final request = _playbackRequestGate.begin();
    _activePlaybackRequest = null;
    return request;
  }

  /// 播放打开后长时间没有画面时按播放失败处理，走重新获取播放地址的恢复流程
  void _startNoVideoWatchdog(int playbackRequest) {
    _noVideoTimer?.cancel();
    _noVideoTimer = Timer(const Duration(seconds: 15), () {
      if (!_isCurrentPlaybackRequest(_roomRequestGate.current, playbackRequest) ||
          _activePlaybackRequest != playbackRequest ||
          player.state.width != null) {
        return;
      }
      Log.d("播放已打开但未收到视频画面");
      _handleMediaFailure(error: "未收到视频画面");
    });
  }

  bool _isCurrentRoomRequest(int request) {
    return !_closed && _roomRequestGate.isCurrent(request);
  }

  bool _isCurrentPlaybackRequest(int roomRequest, int playbackRequest) {
    return _isCurrentRoomRequest(roomRequest) &&
        _playbackRequestGate.isCurrent(playbackRequest);
  }

  Future<void> _enqueuePlayerOperation(
    Future<void> Function() operation,
  ) {
    final next = _playerOperation.then<void>((_) => operation());
    _playerOperation = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Log.logPrint(error);
      },
    );
    return next;
  }

  Future<void> _stopPlayer() async {
    _beginPlaybackRequest();
    try {
      await _enqueuePlayerOperation(() async {
        if (!_closed) {
          await player.stop();
        }
      });
    } catch (e) {
      if (!_closed) {
        Log.logPrint(e);
      }
    }
  }

  /// 读取SC
  Future<void> _getSuperChatMessage({
    required int roomRequest,
    required Site requestSite,
    required LiveRoomDetail roomDetail,
  }) async {
    try {
      final sc = await requestSite.liveSite
          .getSuperChatMessage(roomId: roomDetail.roomId);
      if (!_isCurrentRoomRequest(roomRequest)) {
        return;
      }
      superChats.addAll(sc);
    } catch (e) {
      if (!_isCurrentRoomRequest(roomRequest)) {
        return;
      }
      Log.logPrint(e);
      addSysMsg("SC读取失败");
    }
  }

  /// 移除掉已到期的SC
  void removeSuperChats() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.removeWhere((x) => x.endTime.millisecondsSinceEpoch <= now);
    superChats.refresh();
  }

  /// 添加历史记录
  void addHistory({
    required LiveRoomDetail roomDetail,
    required Site requestSite,
    required String roomId,
  }) {
    final id = "${requestSite.id}_$roomId";
    var history = DBService.instance.getHistory(id);
    if (history != null) {
      history.updateTime = DateTime.now();
    }
    history ??= History(
      id: id,
      roomId: roomId,
      siteId: requestSite.id,
      userName: roomDetail.userName,
      face: roomDetail.userAvatar,
      updateTime: DateTime.now(),
    );

    DBService.instance.addOrUpdateHistory(history);
  }

  /// 关注用户
  void followUser() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    DBService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
      ),
    );
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
      return;
    }

    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  void share() {
    if (detail.value == null) {
      return;
    }
    SharePlus.instance.share(ShareParams(uri: Uri.parse(detail.value!.url)));
  }

  void copyUrl() {
    if (detail.value == null) {
      return;
    }
    Utils.copyToClipboard(detail.value!.url);
    SmartDialog.showToast("已复制直播间链接");
  }

  /// 复制新生成的直播流
  void copyPlayUrl() {
    unawaited(_copyPlayUrl());
  }

  Future<void> _copyPlayUrl() async {
    // 未开播不复制
    final roomDetail = detail.value;
    final qualityIndex = currentQuality;
    if (!liveStatus.value ||
        roomDetail == null ||
        qualityIndex < 0 ||
        qualityIndex >= qualites.length) {
      return;
    }
    final roomRequest = _roomRequestGate.current;
    final requestSite = site;
    final playUrl = await requestSite.liveSite
        .getPlayUrls(detail: roomDetail, quality: qualites[qualityIndex]);
    if (!_isCurrentRoomRequest(roomRequest)) {
      return;
    }
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    Utils.copyToClipboard(playUrl.urls.first);
    SmartDialog.showToast("已复制播放直链");
  }

  /// 底部打开播放器设置
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: danmakuController,
            onTapDanmuShield: () {
              Get.back();
              showDanmuShield();
            },
          ),
        ],
      ),
    );
  }

  void showVolumeSlider(BuildContext targetContext) {
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      displayTime: const Duration(seconds: 3),
      maskColor: const Color(0x00000000),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppStyle.radius12,
            color: Theme.of(context).cardColor,
          ),
          padding: AppStyle.edgeInsetsA4,
          child: Obx(
            () => SizedBox(
              width: 200,
              child: Slider(
                min: 0,
                max: 100,
                value: AppSettingsController.instance.playerVolume.value,
                onChanged: (newValue) {
                  player.setVolume(newValue);
                  AppSettingsController.instance.setPlayerVolume(newValue);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
      child: RadioGroup(
        groupValue: currentQuality,
        onChanged: (e) {
          Get.back();
          currentQuality = e ?? 0;
          getPlayUrl();
        },
        child: ListView.builder(
          itemCount: qualites.length,
          itemBuilder: (_, i) {
            var item = qualites[i];
            return RadioListTile(
              value: i,
              title: Text(item.quality),
            );
          },
        ),
      ),
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: "切换线路",
      child: RadioGroup(
        groupValue: currentLineIndex,
        onChanged: (e) {
          Get.back();
          //currentLineIndex = i;
          //setPlayer();
          changePlayLine(e ?? 0);
        },
        child: ListView.builder(
          itemCount: playUrls.length,
          itemBuilder: (_, i) {
            return RadioListTile(
              value: i,
              title: Text("线路${i + 1}"),
              secondary: Text(
                playUrls[i].contains(".flv") ? "FLV" : "HLS",
              ),
            );
          },
        ),
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      title: "画面尺寸",
      child: Obx(
        () => RadioGroup(
          groupValue: AppSettingsController.instance.scaleMode.value,
          onChanged: (e) {
            AppSettingsController.instance.setScaleMode(e ?? 0);
            updateScaleMode();
          },
          child: ListView(
            padding: AppStyle.edgeInsetsV12,
            children: const [
              RadioListTile(
                value: 0,
                title: Text("适应"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 1,
                title: Text("拉伸"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 2,
                title: Text("铺满"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 3,
                title: Text("16:9"),
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile(
                value: 4,
                title: Text("4:3"),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showDanmuShield() {
    TextEditingController keywordController = TextEditingController();

    void addKeyword() {
      if (keywordController.text.isEmpty) {
        SmartDialog.showToast("请输入关键词");
        return;
      }

      AppSettingsController.instance
          .addShieldList(keywordController.text.trim());
      keywordController.text = "";
    }

    Utils.showBottomSheet(
      title: "关键词屏蔽",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          TextField(
            controller: keywordController,
            decoration: InputDecoration(
              contentPadding: AppStyle.edgeInsetsH12,
              border: const OutlineInputBorder(),
              hintText: "请输入关键词",
              suffixIcon: TextButton.icon(
                onPressed: addKeyword,
                icon: const Icon(Icons.add),
                label: const Text("添加"),
              ),
            ),
            onSubmitted: (e) {
              addKeyword();
            },
          ),
          AppStyle.vGap12,
          Obx(
            () => Text(
              "已添加${AppSettingsController.instance.shieldList.length}个关键词（点击移除）",
              style: Get.textTheme.titleSmall,
            ),
          ),
          AppStyle.vGap12,
          Obx(
            () => Wrap(
              runSpacing: 12,
              spacing: 12,
              children: AppSettingsController.instance.shieldList
                  .map(
                    (item) => InkWell(
                      borderRadius: AppStyle.radius24,
                      onTap: () {
                        AppSettingsController.instance.removeShieldList(item);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: AppStyle.radius24,
                        ),
                        padding: AppStyle.edgeInsetsH12.copyWith(
                          top: 4,
                          bottom: 4,
                        ),
                        child: Text(
                          item,
                          style: Get.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void showFollowUserSheet() {
    Utils.showBottomSheet(
      title: "关注列表",
      child: Obx(
        () => Stack(
          children: [
            RefreshIndicator(
              onRefresh: FollowService.instance.loadData,
              child: ListView.builder(
                itemCount: FollowService.instance.liveList.length,
                itemBuilder: (_, i) {
                  var item = FollowService.instance.liveList[i];
                  return Obx(
                    () => FollowUserItem(
                      item: item,
                      playing: rxSite.value.id == item.siteId &&
                          rxRoomId.value == item.roomId,
                      onTap: () {
                        Get.back();
                        resetRoom(
                          Sites.allSites[item.siteId]!,
                          item.roomId,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned(
                right: 12,
                bottom: 12,
                child: Obx(
                  () => DesktopRefreshButton(
                    refreshing: FollowService.instance.updating.value,
                    onPressed: FollowService.instance.loadData,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void showAutoExitSheet() {
    if (AppSettingsController.instance.autoExitEnable.value &&
        !delayAutoExit.value) {
      SmartDialog.showToast("已设置了全局定时关闭");
      return;
    }
    Utils.showBottomSheet(
      title: "定时关闭",
      child: ListView(
        children: [
          Obx(
            () => SwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Get.textTheme.titleMedium,
              ),
              value: autoExitEnable.value,
              onChanged: (e) {
                autoExitEnable.value = e;

                setAutoExit();
                //controller.setAutoExitEnable(e);
              },
            ),
          ),
          Obx(
            () => ListTile(
              enabled: autoExitEnable.value,
              title: Text(
                "自动关闭时间：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟",
                style: Get.textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var value = await showTimePicker(
                  context: Get.context!,
                  initialTime: TimeOfDay(
                    hour: autoExitMinutes.value ~/ 60,
                    minute: autoExitMinutes.value % 60,
                  ),
                  initialEntryMode: TimePickerEntryMode.inputOnly,
                  builder: (_, child) {
                    return MediaQuery(
                      data: Get.mediaQuery.copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child!,
                    );
                  },
                );
                if (value == null || (value.hour == 0 && value.minute == 0)) {
                  return;
                }
                var duration =
                    Duration(hours: value.hour, minutes: value.minute);
                autoExitMinutes.value = duration.inMinutes;
                AppSettingsController.instance
                    .setRoomAutoExitDuration(autoExitMinutes.value);
                //setAutoExitDuration(duration.inMinutes);
                setAutoExit();
              },
            ),
          ),
        ],
      ),
    );
  }

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == Constant.kBiliBili) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyin) {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://live.douyin.com/${args.webRid}";
    } else if (site.id == Constant.kHuya) {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyu) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    rxSite.value = site;
    rxRoomId.value = roomId;
    _roomRequestGate.invalidate();

    // 清除全部消息
    liveDanmaku.stop();
    messages.clear();
    superChats.clear();
    danmakuController?.clear();

    // 重新设置LiveDanmaku
    liveDanmaku = site.liveSite.getDanmaku();

    // 停止播放
    await _stopPlayer();
    if (_closed) {
      return;
    }

    // 刷新信息
    await loadData();

    // 恢复弹幕
    danmakuController?.resume();
  }

  void copyErrorDetail() {
    Utils.copyToClipboard('''直播平台：${rxSite.value.name}
房间号：${rxRoomId.value}
错误信息：
${error?.toString()}
----------------
${error?.stackTrace}''');
    SmartDialog.showToast("已复制错误信息");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      Log.d("进入后台");
      //进入后台，关闭弹幕
      danmakuController?.clear();
      isBackground = true;
    } else
    //返回前台
    if (state == AppLifecycleState.resumed) {
      Log.d("返回前台");
      danmakuController?.resume();
      isBackground = false;
      unawaited(_recoverAfterResume());
    }
  }

  /// 回前台只在后台确实丢失播放、或位置确认不再前进时才恢复。
  /// 故障标记优先；探测进行中时忽略后续 resumed，避免反复重连。
  Future<void> _recoverAfterResume() async {
    final roomRequest = _roomRequestGate.current;
    final playbackRequest = _playbackRequestGate.current;
    if (_closed || !liveStatus.value || !recovery.beginResumeProbe()) {
      return;
    }
    try {
      // 后台确实失败/EOF：优先恢复，不因播放器暂停状态跳过
      if (recovery.lostWhileBackgrounded) {
        if (_mediaRecoveryInProgress) {
          return;
        }
        recovery.lostWhileBackgrounded = false;
        Log.d("后台播放已中断，返回前台重新获取播放地址");
        await _reloadPlayUrl();
        return;
      }
      // 静默停滞探测：短时间窗口内位置没有前进才恢复，暂停的播放器不打扰
      final positionBefore = player.state.position;
      await Future.delayed(const Duration(seconds: 3));
      if (_closed ||
          isBackground ||
          !_isCurrentPlaybackRequest(roomRequest, playbackRequest) ||
          _mediaRecoveryInProgress) {
        return;
      }
      if (!recovery.shouldRecoverOnStall(
        positionAdvanced: player.state.position > positionBefore,
        playing: player.state.playing,
      )) {
        return;
      }
      Log.d("返回前台后画面没有前进，重新获取播放地址");
      await _reloadPlayUrl();
    } finally {
      recovery.endResumeProbe();
    }
  }

  // 用于启动开播时长计算和更新的函数
  void startLiveDurationTimer() {
    // 如果不是直播状态或者 showTime 为空，则不启动定时器
    if (!(detail.value?.status ?? false) || detail.value?.showTime == null) {
      liveDuration.value = "00:00:00"; // 未开播时显示 00:00:00
      _liveDurationTimer?.cancel();
      return;
    }

    try {
      int startTimeStamp = int.parse(detail.value!.showTime!);
      // 取消之前的定时器
      _liveDurationTimer?.cancel();
      // 创建新的定时器，每秒更新一次
      _liveDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        int durationInSeconds = currentTimeStamp - startTimeStamp;

        int hours = durationInSeconds ~/ 3600;
        int minutes = (durationInSeconds % 3600) ~/ 60;
        int seconds = durationInSeconds % 60;

        String formattedDuration =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        liveDuration.value = formattedDuration;
      });
    } catch (e) {
      liveDuration.value = "--:--:--"; // 错误时显示 --:--:--
    }
  }

  @override
  void onClose() {
    _closed = true;
    _roomRequestGate.close();
    _playbackRequestGate.close();
    _activePlaybackRequest = null;
    WidgetsBinding.instance.removeObserver(this);
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    autoExitTimer?.cancel();
    _noVideoTimer?.cancel();
    _positionSubscription?.cancel();

    liveDanmaku.stop();
    danmakuController = null;
    _liveDurationTimer?.cancel(); // 页面关闭时取消定时器
    super.onClose();
  }
}
