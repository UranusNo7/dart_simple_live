# Windows and Android phone navigation

## Scope

This document describes the simplified navigation for the primary `simple_live_app` client on Windows and Android phones. The Android TV client is outside this change.

## Navigation

The primary client now has three fixed destinations:

- 首页
- 关注
- 我的

分类页面、分类详情路由和主页导航排序入口 were removed from the primary client. The shared `simple_live_core` category APIs remain because they are still part of the repository's shared client contract.

Android phone navigation shows both icons and labels in the bottom navigation bar. Windows uses a compact navigation rail that shows the selected destination label.

## Existing configuration migration

Older installations may have a reordered `HomeSort` value containing `category`. Startup replaces it with the fixed `recommend,follow,user` order and writes the normalized value back. Other settings keys are retained so importing an older configuration does not require deleting unrelated user data.

## Settings surface

The primary "我的" page keeps history, account management, synchronization, link parsing, appearance, playback, danmaku, follow refresh, and timer functions. The former home-ordering entry and ordinary entry to advanced settings were removed from the main list. The advanced settings route and stored values remain available for compatibility and future deliberate exposure.

The follow page no longer exposes manual update-concurrency tuning; the existing automatic concurrency implementation and stored key remain unchanged.

## Player configuration

The primary client no longer exposes decoder, renderer, audio output, buffer, compatibility, hardware acceleration, or forced-HTTPS switches. The player uses fixed device-oriented configurations:

- Windows: `libmpv` video output, automatic hardware decoding, and hardware acceleration.
- Android phones: `gpu` video output, safe automatic hardware decoding, and hardware acceleration.

These choices are maintained in `app/player_config/` and apply automatically at player creation.

## Full-screen transition

On Android, the player marks the Flutter page as full-screen before requesting landscape orientation. This keeps the player and danmaku in one full-screen layer while the device rotates, instead of allowing the normal landscape two-column room layout to appear during the transition.

The ordinary room page uses the available width instead of orientation alone to
choose its layout. Android phones always use the single-column room page. On
Windows, the two-column player/chat layout is enabled at 900 logical pixels or
more; narrower windows use the phone-style single-column layout.

Room refreshes and room switches invalidate their previous asynchronous requests.
Player open, line switching, and stop operations are serialized so a late result
from the previous room cannot replace the current player state.

## Live stream recovery

Room addresses are signed and short-lived. A Douyu address carries `expire=300`, and in the captured session the connection was reset roughly every 300 seconds, matching that value. The client cannot tell which hop performs the reset, so it does not claim to prevent it and adds no scheduled refresh.

The room controller reacts to playback failure with a bounded policy instead of an open-ended reconnect loop:

- Douyu opens only the selected line rather than the whole returned address list, so the player cannot fall back to another CDN host on its own. Other sites keep the multi-line playlist.
- Switching lines re-opens the selected address. `player.jump` only moves the position inside the already-loaded list, so it is not used for that purpose.
- On EOF or a playback error, Douyu fetches a fresh address immediately instead of retrying the old one. Other sites try the same address a bounded number of times first.
- The refresh budget is returned only after the playback position of the current playback attempt has advanced by a few seconds. Opening a stream, or a `playing` event, is not treated as a successful recovery, so an unusable address cannot cause rapid repeated reconnects. The check is a position delta, not a measurement of continuous playback.
- Returning to the foreground recovers only when playback was lost in the background or when the position is confirmed not to advance. A normally playing stream and a paused player are left untouched, overlapping probes are dropped, and a probe whose room was closed, replaced, or returned to the background is discarded.
- The last remaining line is only reported as offline after the site itself reports the room has ended.

Recovery is driven by playback events only. There is no scheduled periodic refresh and no time-based filtering of failures, because that would also discard genuine ones.

Known limit: a player event that belongs to a superseded playback attempt can still arrive after a new attempt has started. Recovery relies on the request-generation guards and on opening a single line rather than on completely shielding stale events, so a late event may still start one extra recovery attempt.

## Build compatibility

The verified toolchain is Flutter 3.44.6 with Dart 3.12.2. This matches the locked `volume_controller 3.6.0` SDK requirement and the native-asset hook format stored in the generated package state.

Flutter 3.44.6 adds `android.builtInKotlin=false` and `android.newDsl=false` to the Android Gradle properties when migrating this existing project. The generated Windows plugin registrant is refreshed for the current `screen_brightness_windows` C API and FFI plugin list. These generated changes are required by the verified Windows and Android release builds; no package constraint or lock-file version changed.

The primary app release workflow publishes only the Android `arm64-v8a` APK. The Android TV workflow and development artifact workflow are unchanged.
