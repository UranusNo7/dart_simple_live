# UI and performance audit

## Scope

The audit covered the Flutter application startup path, main navigation, home/category/search pagination, image cards, live-room rendering, player controls, danmaku integration, timers, subscriptions, and controller disposal.

The review was source-based and used focused widget tests and static analysis. It did not change network protocols, playback backends, danmaku concurrency, authentication, or dependency versions.

## Implemented changes

- Live-room loading now uses request generations for room details, SuperChat data,
  danmaku callbacks, quality lists, and play URLs. A newer refresh, room switch,
  or page close invalidates older work before it can update the current room.
- Player `open`, `jump`, and `stop` operations are serialized. Playback recovery
  is guarded against duplicate end/error callbacks and player errors are routed
  through the error callback instead of the normal completion callback.
- Ordinary live-room layout now uses a width breakpoint on Windows. Android
  phones keep the single-column layout even when the device is temporarily in
  landscape; the wide two-column layout starts at 900 logical pixels on desktop.
- Fixed-size network images automatically request a device-pixel-sized decode
  when no explicit cache width is supplied. Loading and failure placeholders
  keep the requested image bounds, reducing layout shifts.
- Player control bars and lock controls keep their 200 ms duration but use `Curves.easeOutCubic` for a smoother stop.
- Shared scroll-to-top behavior uses the same decelerating curve instead of linear motion.
- Player SuperChat rendering uses one countdown timer per visible card. The previous implementation combined an overlay timer, a wrapper timer, and the card countdown stream.
- Volume and brightness drag handlers no longer write logs for every pointer update. This avoids debug-list mutations and optional file I/O on a frame-sensitive path.
- Windows fullscreen transitions now keep native window geometry handling (unmaximize before fullscreen and maximize after) to preserve correct maximized-state restore, but update Flutter layout state in sync with the native transition and unify ESC, mouse side-button, and player controls through one exit path. A transition guard prevents overlapping enter/exit requests. An attempt to eliminate the visible window-size intermediate step was reverted because it broke maximized-window fullscreen on this `window_manager` version.
- Player cleanup now calls the Floating PiP plugin's `cancelOnLeavePiP` method only on Android/iOS; the Windows profile run had reproduced a `MissingPluginException` from that mobile-only method.
- A widget regression test verifies that a custom SuperChat countdown ticks to zero and emits expiration once.

## Findings kept out of this change

- `flutter_easyrefresh 2.2.2` is discontinued. The current pagination widgets intentionally keep `EasyRefresh` directly above their scroll views because this dependency requires that hierarchy. Replacing it needs a separate migration with refresh/load/empty/error coverage.
- Home, category, and search retain one controller per supported site. Their lifetime is bounded by the owning page controllers, and changing this to lazy controller creation would affect refresh and tab-state behavior. Profile data should justify that change first.
- Live chat uses reactive list rebuilding, but the controller already coalesces scroll scheduling and trims messages after the hard limit. Any deeper change should be driven by Flutter DevTools frame and rebuild traces from a high-message-rate room.
- Danmaku rendering and player streams remain untouched. They are core real-time paths and require device-level profile captures before changing scheduling or concurrency.
- Message list batching remains intentionally deferred. The current reactive
  list is bounded, but batching would trade UI rebuilds for message latency and
  needs a high-rate room profile before changing that behavior.

## Verification

Run the focused checks from `simple_live_app`:

```powershell
flutter test test/widget_test.dart test/page_views_test.dart --reporter expanded
flutter analyze --no-pub lib/app/controller/base_controller.dart lib/widgets/superchat_card.dart lib/modules/live_room/player/player_controller.dart lib/modules/live_room/player/player_controls.dart test/widget_test.dart
flutter test test/live_room_stability_test.dart --reporter expanded
flutter analyze --no-pub lib/modules/live_room/live_room_controller.dart lib/modules/live_room/live_room_page.dart lib/widgets/net_image.dart test/live_room_stability_test.dart
```

For runtime profiling, use a physical target or the Windows release/profile build. Capture Flutter DevTools frame timing while:

1. Scrolling a loaded home grid.
2. Showing and hiding player controls repeatedly.
3. Dragging volume and brightness on mobile.
4. Displaying several simultaneous SuperChat messages.

A follow-up optimization should require reproducible raster or UI frame misses, excessive rebuild counts, or sustained CPU/memory growth in one of these scenarios.

## Executed Windows profile baseline

- Toolchain: Flutter 3.44.6, Dart 3.12.2, Windows desktop profile mode.
- Clean startup trace before the platform guard: first frame 282.8 ms (`build/start_up_info.json`); after the guard and regenerated plugin registration: first frame 254 ms.
- The profile run observed Direct3D 11 hardware rendering and video textures at 1280x720 and 1920x1080.
- A 10-second process sample during plugin/video initialization grew from about 27 MB to 380–400 MB working set, about 15 MB to 680–736 MB private memory, 6 to about 230 threads, and 241 to about 1,682 handles. This is an initialization baseline, not proof that the Dart UI is responsible; no optimization is justified from this sample alone.
- The first run reproduced `MissingPluginException(No implementation found for method cancelAutoEnable on channel floating)` during Windows player cleanup. The platform guard was added and a subsequent profile startup completed without that exception.

The current machine has no Android/iOS device, and no reliable automated route was available for DevTools frame-timing captures while manually scrolling, dragging gestures, or displaying multiple SuperChats. Those scenarios remain manual/device validation items rather than claimed pass results.
