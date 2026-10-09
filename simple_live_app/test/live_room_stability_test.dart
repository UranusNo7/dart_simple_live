import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

void main() {
  test('a newer room request invalidates an older request', () {
    final gate = LiveRoomRequestGate();

    final firstRequest = gate.begin();
    final secondRequest = gate.begin();

    expect(gate.isCurrent(firstRequest), isFalse);
    expect(gate.isCurrent(secondRequest), isTrue);
  });

  test('closing the room invalidates outstanding requests', () {
    final gate = LiveRoomRequestGate();
    final request = gate.begin();

    gate.close();

    expect(gate.isCurrent(request), isFalse);
  });

  test('offline state requires an explicit live-status result', () {
    expect(
      shouldMarkLiveOffline(
        isBackground: true,
        error: null,
        confirmedLiveStatus: false,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: false,
      ),
      isTrue,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: true,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: null,
        confirmedLiveStatus: null,
      ),
      isFalse,
    );
    expect(
      shouldMarkLiveOffline(
        isBackground: false,
        error: 'connection lost',
        confirmedLiveStatus: false,
      ),
      isFalse,
    );
  });

  test('live-status recovery is checked only once per playback cycle', () {
    expect(
      shouldCheckLiveStatus(
        isBackground: false,
        error: null,
        recoveryAttempted: false,
      ),
      isTrue,
    );
    expect(
      shouldCheckLiveStatus(
        isBackground: false,
        error: null,
        recoveryAttempted: true,
      ),
      isFalse,
    );
    expect(
      shouldCheckLiveStatus(
        isBackground: true,
        error: null,
        recoveryAttempted: false,
      ),
      isFalse,
    );
  });

  group('LivePlaybackRecovery', () {
    test('Douyu skips retrying the expired address and refreshes right away', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(recovery.sameUrlRetries, 0);
      expect(recovery.urlRefreshes, 1);
    });

    test('other sites retry the same address before refreshing', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: false);

      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: 'connection lost',
        ),
        LiveRecoveryAction.retryCurrentUrl,
      );
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: 'connection lost',
        ),
        LiveRecoveryAction.retryCurrentUrl,
      );
      expect(recovery.sameUrlRetries, 2);
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: 'connection lost',
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
    });

    test('an exhausted budget falls back to lines then live-status only once',
        () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.switchLine,
      );
      expect(
        recovery.planFailure(
          hasMoreLines: false,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.confirmLiveStatus,
      );
      expect(
        recovery.planFailure(
          hasMoreLines: false,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.giveUp,
      );
    });

    test('a background failure is remembered for the next foreground resume',
        () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      expect(recovery.lostWhileBackgrounded, isFalse);
      recovery.markFailure(isBackground: false);
      expect(recovery.lostWhileBackgrounded, isFalse,
          reason: '前台失败不需要回前台恢复');
      recovery.markFailure(isBackground: true);
      expect(recovery.lostWhileBackgrounded, isTrue);
    });

    test('the refresh budget comes back only after sustained progress', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      // 第一次地址过期：立即刷新并消耗预算
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      // 仅仅 open 成功、位置没有前进：不归还预算
      expect(recovery.onPlaybackProgress(Duration.zero), isFalse);
      expect(recovery.urlRefreshes, 1);
      // 重新 open 后位置从 0 开始，短暂播放不到阈值：仍然不归还
      expect(recovery.onPlaybackProgress(const Duration(seconds: 2)), isFalse);
      expect(recovery.urlRefreshes, 1);
      // 持续播放超过阈值：归还预算，下一次过期可以再次刷新
      expect(recovery.onPlaybackProgress(const Duration(seconds: 6)), isTrue);
      expect(recovery.urlRefreshes, 0);
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
    });

    test('a position reset starts a new progress session', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      // 第一轮已经播放到 300 秒，刷新消耗的预算在继续前进后归还
      recovery.onPlaybackProgress(const Duration(seconds: 300));
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(recovery.urlRefreshes, 1);
      expect(recovery.onPlaybackProgress(const Duration(seconds: 306)), isTrue);
      expect(recovery.urlRefreshes, 0);

      // 第二轮再次过期刷新后位置重置回 0，必须重新累计到阈值
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(recovery.urlRefreshes, 1);
      expect(recovery.onPlaybackProgress(Duration.zero), isFalse);
      expect(recovery.onPlaybackProgress(const Duration(seconds: 1)), isFalse);
      expect(recovery.urlRefreshes, 1,
          reason: '位置重置后不足阈值不能归还预算');
      expect(recovery.onPlaybackProgress(const Duration(seconds: 6)), isTrue);
      expect(recovery.urlRefreshes, 0);
    });

    test('real progress also clears the background-loss and status flags', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      recovery.markFailure(isBackground: true);
      expect(recovery.lostWhileBackgrounded, isTrue);
      expect(
        recovery.planFailure(
          hasMoreLines: false,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(
        recovery.planFailure(
          hasMoreLines: false,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.confirmLiveStatus,
      );
      expect(recovery.liveStatusChecked, isTrue);

      // 本轮第一个位置事件只作为基准，前进到阈值后才清标记
      recovery.armNewPlaybackSession();
      expect(recovery.onPlaybackProgress(const Duration(seconds: 6)), isFalse);
      expect(recovery.lostWhileBackgrounded, isTrue);
      expect(recovery.onPlaybackProgress(const Duration(seconds: 12)), isTrue);

      expect(recovery.lostWhileBackgrounded, isFalse);
      expect(recovery.liveStatusChecked, isFalse);
      expect(recovery.urlRefreshes, 0);
    });

    test('a stale position cannot restore the budget for a new playback', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      // 上一轮播放到 300 秒并消耗了刷新预算
      recovery.armNewPlaybackSession();
      recovery.onPlaybackProgress(const Duration(seconds: 300));
      expect(
        recovery.planFailure(
          hasMoreLines: true,
          isBackground: false,
          error: null,
        ),
        LiveRecoveryAction.refreshPlayUrl,
      );
      expect(recovery.urlRefreshes, 1);

      // 新 open 之前到达的旧位置事件只作为本轮基准，不能瞬间归还预算
      recovery.armNewPlaybackSession();
      expect(recovery.onPlaybackProgress(const Duration(seconds: 300)), isFalse);
      expect(recovery.urlRefreshes, 1, reason: '旧位置事件不能归还预算');

      // 新流没有把位置归零，继续前进也必须满足阈值
      expect(recovery.onPlaybackProgress(const Duration(seconds: 301)), isFalse);
      expect(recovery.urlRefreshes, 1);
      expect(recovery.onPlaybackProgress(const Duration(seconds: 306)), isTrue);
      expect(recovery.urlRefreshes, 0);
    });

    test('overlapping resume probes are dropped', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      expect(recovery.beginResumeProbe(), isTrue);
      expect(recovery.beginResumeProbe(), isFalse);
      recovery.endResumeProbe();
      expect(recovery.beginResumeProbe(), isTrue);
    });

    test('a stalled stream needs recovery, a playing or paused one does not', () {
      final recovery = LivePlaybackRecovery(refreshUrlsOnFailure: true);

      // 静默停滞：播放器没有被暂停但位置没有前进
      expect(
        recovery.shouldRecoverOnStall(positionAdvanced: false, playing: true),
        isTrue,
      );
      // 正常播放
      expect(
        recovery.shouldRecoverOnStall(positionAdvanced: true, playing: true),
        isFalse,
      );
      // 播放器处于暂停状态：不打扰
      expect(
        recovery.shouldRecoverOnStall(positionAdvanced: false, playing: false),
        isFalse,
      );
    });
  });

  test('Android phones keep the single-column room layout in landscape', () {
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: true, width: 1200),
      isFalse,
    );
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: false, width: 899),
      isFalse,
    );
    expect(
      shouldUseWideLiveRoomLayout(isAndroid: false, width: 900),
      isTrue,
    );
  });
}
