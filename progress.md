## 2026-08-01 - Task: Prepare the repository source tree for public release

### What was done

- Replaced maintainer and platform display metadata that exposed the upstream contact identity with generic values.
- Removed the iOS development-team identifier, captured request sample values, and the tracked Android build report containing a local path.
- Stopped Issue templates from assigning new reports to the upstream account while preserving required license attribution and package identifiers.
- Added public-release documentation describing retained compatibility identifiers and the separate history-rewrite boundary.

### Testing

- Current-tree privacy scan found no real email, local path, signing-team identifier, or captured token; only the intentional `.invalid` placeholder remains.
- YAML and JSON parsing passed with `yaml-json-parse-ok`.
- `git diff --check` passed.
- `flutter test --reporter expanded` passed: 3 tests passed.
- `flutter analyze` completed with exit code 1 because five unrelated info-level diagnostics remain in untouched Flutter files (`onReorder`, QR controller disposal, and an unnecessary import); no error-level diagnostics were reported.

### Notes

- `.github/ISSUE_TEMPLATE/bug.yml`: removed the upstream default assignee.
- `.github/ISSUE_TEMPLATE/feature.yml`: removed the upstream default assignee and original maintainer voice.
- `simple_live_app/.gitignore`: excludes the Android build directory.
- `simple_live_app/ios/Runner.xcodeproj/project.pbxproj`: removed the upstream Apple development-team identifier.
- `simple_live_app/linux/packaging/deb/make_config.yaml`: replaced the maintainer contact with a non-routable placeholder.
- `simple_live_app/macos/Runner/Configs/AppInfo.xcconfig`: replaced platform display copyright metadata.
- `simple_live_app/windows/packaging/msix/make_config.yaml`: replaced the publisher display name.
- `simple_live_app/windows/runner/Runner.rc`: replaced Windows display company and copyright metadata.
- `simple_live_core/lib/src/scripts/douyin_sign.dart`: redacted captured request sample values in comments only.
- `simple_live_app/android/build/reports/problems/problems-report.html`: removed the tracked local build report.
- `docs/public-release.md`: records the public-release boundary and retained compatibility data.
- `progress.md`: records this task and its rollback point.
- Rollback point: restore commit `ad72a456a08199da697bb6e9c0dce1e91b8ea006`; before pushing, review and revert this new commit with `git revert <commit>` if needed.

## 2026-08-02 - Task: Sanitize fork history and publish the repository

### What was done

- Rewrote only the fork-specific commit range after `upstream/master`, replacing the personal school email in 33 commits with the GitHub noreply address while preserving inherited upstream history.
- Force-updated the rewritten `master` branch and 24 affected tags; retained the existing releases and release assets.
- Deleted the 24 Actions runs that referenced pre-rewrite commit SHAs, then restored the release workflows without triggering historical rebuilds.
- Changed `UranusNo7/dart_simple_live` from private to public after the user explicitly accepted that GitHub still serves orphaned old commits containing the previous email metadata.

### Testing

- Verified all 1,097 `upstream/master` commit hashes were unchanged and the rewritten fork commits retained their trees, messages, dates, and author names.
- Verified the 33 affected commits now use `74861408+UranusNo7@users.noreply.github.com` and all 91 local and remote tag refs match.
- Verified the Actions run list is empty after deleting exactly 24 historical runs.
- Verified the `v1.11.6-fix`, `dev-ad72a45`, and `dev-00b16e6` releases retain all 9 assets in total.
- Verified GitHub reports the repository as `PUBLIC` and `isPrivate=false`; anonymous repository and release-page requests returned HTTP 200, and the APK URL returned the expected HTTP 302 asset redirect.
- Verified three release workflows remained active. The TV release workflow file was touched with a comment-only change so GitHub can register it again after the history rewrite; its final remote state is checked after this commit is pushed.
- Confirmed the accepted residual risk: old orphaned SHAs remain anonymously reachable and expose `2023120205@njpji.edu.cn` in commit metadata.

### Notes

- `.github/workflows/publish_tv_app_release.yaml`: changed one comment only to trigger GitHub to re-register the existing TV tag release workflow.
- `progress.md`: recorded the scoped history rewrite, Actions cleanup, release preservation, accepted residual email exposure, and public visibility verification.
- Full rollback mirror: `D:\python_code\dart_simple_live-history-backup-20260802-003723.git`.
- Full rollback bundle: `D:\python_code\dart_simple_live-history-backup-20260802-003723.bundle`.
- Visibility rollback: `gh repo edit UranusNo7/dart_simple_live --visibility private --accept-visibility-change-consequences`.
- History rollback must be performed only after making the repository private: force-push `master` and tags from the verified mirror, or restore from the verified bundle. Deleted Actions runs cannot be restored.

## 2026-08-02 - Task: Add automatic reconnect for Douyu danmaku startup failures

### What was done

- Added a default-off initial connection failure retry option to the shared WebSocket utility and enabled it only for Douyu danmaku connections.
- Reused the existing five-second reconnect interval and reconnect limit instead of adding a second retry mechanism.
- Added deterministic local WebSocket regression coverage for recovery after two rejected handshakes and for cancelling retries when leaving the live room.
- Documented the Douyu-specific reconnect behavior and lifecycle boundary.

### Testing

- Before the fix, `dart test test/douyu_danmaku_reconnect_test.dart --reporter expanded` failed because no third connection was attempted after two HTTP 503 handshake responses.
- After the fix, the same command passed both tests in 11 seconds: recovery succeeded on the third request, and `stop()` prevented any request after the pending five-second retry interval.
- `dart analyze` completed with no new diagnostics. It remains exit code 1 because of 21 existing diagnostics in unrelated files: 2 warnings and 19 info-level items.
- `git diff --check` passed.

### Notes

- `simple_live_core/lib/src/common/web_socket_util.dart`: added the default-off retry-on-initial-connect-failure option and routed opted-in failures into the existing reconnect cycle.
- `simple_live_core/lib/src/danmaku/douyu_danmaku.dart`: enabled initial connection failure retries for Douyu only.
- `simple_live_core/test/douyu_danmaku_reconnect_test.dart`: covers delayed recovery and retry cancellation using a local WebSocket server.
- `docs/douyu-danmaku-reconnect.md`: documents retry scope, interval, limit, and shutdown behavior.
- `progress.md`: records implementation, verification, changed files, and rollback instructions.
- Rollback point: commit `c71f3645017d9003cc07becd8113107d09e8cf82`; after this task is committed, revert the new commit with `git revert <new-commit>`.

## 2026-08-02 - Task: Build and publish v1.11.7-fix with GitHub Actions

### What was done

- Created annotated tag `v1.11.7-fix` at Douyu reconnect commit `c9b8445ef6a4542b441850f060666ff5849e90f3` using the generic noreply identity.
- Triggered the tag-based `app-build-action` workflow and monitored run `30736455813` through both jobs.
- Published GitHub Release `v1.11.7-fix` with a Windows ZIP and three split-ABI Android APKs.

### Testing

- GitHub Actions run `30736455813` completed successfully: `build-windows` passed in 10m41s and `build-android` passed in 10m42s.
- Verified Release `363720956` is the repository's latest release and is neither a draft nor a prerelease.
- Verified all four assets report `state=uploaded` and public download URLs return valid HTTP 302 redirects; the public release page returns HTTP 200.
- `app-arm64-v8a-release.apk`: 40,447,680 bytes, SHA-256 `6248490fad36ffdcd8b6424cfc3fbabeb518da447aa5c3d58ba335421ace777e`.
- `app-armeabi-v7a-release.apk`: 38,153,376 bytes, SHA-256 `e6df6308eb1c94939f1fa050bcb55c7f8c6bbe9674000be8f17f308735f32a32`.
- `app-x86_64-release.apk`: 45,418,026 bytes, SHA-256 `c2414a50f313c2e7b960e8ca8f1b397a9d40e4aaa764ed7ffa0da6bd4c93c69a`.
- `simple_live_app-v1.11.7-fix-windows.zip`: 37,324,082 bytes, SHA-256 `316d4b38dfdbbc8cec1c25b590bd58bc60d6532ccfd4dc66436af28d409ab2f0`.
- Full local re-download and independent digest calculation were not completed because the GitHub asset connection was too slow; the arm64 download transferred about 9.6 MB before the verification download was stopped. Sizes and digests above are GitHub's server-side release metadata.

### Notes

- `progress.md`: recorded the Action run, release identity, artifact sizes and digests, public download checks, and verification limitation.
- The workflow emitted Node.js 20 deprecation warnings for existing third-party actions; GitHub ran them on Node.js 24 and both jobs succeeded.
- Release rollback: `gh release delete v1.11.7-fix --repo UranusNo7/dart_simple_live --yes`, then `git push origin :refs/tags/v1.11.7-fix` and `git tag -d v1.11.7-fix`.

## 2026-08-22 - Task: Fix Windows fullscreen misalignment when entering from maximized window

### What was done

- Fixed the bug where clicking fullscreen while the window was maximized caused the window to be misplaced after exiting fullscreen (a known window_manager issue on Windows).
- The fix now records the maximized state, unmaximizes before entering fullscreen, and restores the maximized state after exiting.
- Unified all desktop fullscreen exit paths (player controls, ESC key, mouse side button) to go through the same helper so the maximize state is always restored.
- Investigated Windows UI smoothness: danmaku rendering already isolates repaints internally; no evidence-backed code change was made for smoothness in this round (see Notes for follow-up options).

### Testing

- `flutter analyze --no-pub lib/main.dart lib/modules/live_room/player/player_controller.dart lib/app/utils/window_utils.dart`: No issues found.
- `flutter build windows --release` on local Flutter 3.44.6: succeeded, produced `simple_live_app/build/windows/x64/runner/Release/simple_live_app.exe`.
  - Local build required two environment-only workarounds (no repo changes): temporarily removing bogus windows/macos/linux platform declarations from the pub-cache copy of `auto_orientation_v2-2.4.5` (cache dir deleted afterwards so it re-extracts pristine), and setting `_CL_=utf-8` plus a local `nuget.exe` on PATH for the Chinese-locale MSVC toolchain. CI builds with Flutter 3.38.x are unaffected by all three.
- Smoke test: launched the built exe; process stayed alive for 10 seconds, then was terminated manually.
- Gap: actual fullscreen enter/exit behavior under a maximized window needs one manual GUI verification pass; automated verification of window placement was not available.

### Notes

- `simple_live_app/lib/app/utils/window_utils.dart`: new shared desktop fullscreen helper (`enterFullScreen`/`exitFullScreen`) that remembers and restores the maximized state.
- `simple_live_app/lib/modules/live_room/player/player_controller.dart`: `enterFullScreen`/`exitFull` desktop branches now call the helper instead of calling `windowManager.setFullScreen` directly.
- `simple_live_app/lib/main.dart`: ESC key and mouse side-button handlers now call `WindowUtils.exitFullScreen()` instead of `windowManager.setFullScreen(false)`.
- Rollback: revert the two modified files and delete `lib/app/utils/window_utils.dart`, or `git checkout e17b585 -- simple_live_app/lib/main.dart simple_live_app/lib/modules/live_room/player/player_controller.dart && git clean -f simple_live_app/lib/app/utils/window_utils.dart`.

## 2026-08-22 - Task: Publish v1.11.8-fix via GitHub Actions

### What was done

- Published GitHub Release `v1.11.8-fix` (Windows ZIP + three split-ABI Android APKs) from run `32519665567` on `UranusNo7/dart_simple_live`.
- Restored the broken CI Windows build by pinning `auto_orientation_v2` to a version without bogus desktop platform declarations (2.3.8).
- Restored the Android build by pinning `dynamic_color` to 1.8.1 (1.9.0 published 2026-08-07 is incompatible with the project's Gradle setup) and by avoiding auto_orientation_v2 2.4.x's inconsistent Android JVM targets.
- Both pins were required because the repo ignores `pubspec.lock`, so CI re-resolves floating constraints on every build and had drifted onto dependencies published after the v1.11.7-fix release.

### Testing

- Run `32519665567`: `build-windows` succeeded in 8m5s, `build-android` succeeded in 10m22s.
- Release verified via `gh release view`: 4 assets all `state=uploaded`, `isDraft=false`, `isPrerelease=false`, listed as Latest.
- Local verification before pushing: `flutter build windows --release` succeeded with the pinned versions (no cache workarounds needed for the dependency issue).
- Two earlier runs failed during iteration (`32515920799`: auto_orientation CMake error; `32518046375`: dynamic_color Gradle error, then auto_orientation JVM-target error); one doomed run `32519540908` was cancelled after a mis-pathed local commit; all three tag states were superseded before any user-facing artifact was consumed.

### Notes

- `simple_live_app/pubspec.yaml`: pinned `auto_orientation_v2: 2.3.8` and `dynamic_color: 1.8.1` with explanatory comments.
- Remote `master` fast-forwarded to `8baa65a` via branch `win-fullscreen-fix`; tag `v1.11.8-fix` points at `8baa65a`. Local `migration` branch received the same commits via cherry-pick (`06f0ca7`/`82f9ab4`/`121599a` line).
- Note: remote master history is still the pre-sanitization lineage; publishing used fast-forward only, no force-push.
- Rollback: delete release `v1.11.8-fix` and tag, then revert commits `8baa65a`/`b0e82ef`/`6364ebd`/`66866ab` on remote master.
## 2026-08-22 - Task: Simplify UI behavior and improve player responsiveness

### What was done

- Audited the Flutter startup path, navigation, pagination, live-room UI, player controls, timers, subscriptions, and controller disposal without changing network protocols, playback backends, authentication, or dependency versions.
- Made player control and shared scroll-to-top animations use Curves.easeOutCubic while preserving the existing 200 ms duration and destinations.
- Reduced SuperChat overlay timer ownership from an overlay timer plus wrapper timer plus card stream to one cancellable countdown timer per visible card; the card now updates its display and expires exactly once.
- Removed per-pointer-event logging from mobile volume and brightness gestures to avoid debug-list mutations and optional file writes on frame-sensitive paths.
- Added a widget regression test for SuperChat countdown ticking and one-time expiration.
- Added an audit document with deliberate non-changes and profiling gates, and documented the repository structure.

### Testing

- lutter test test/widget_test.dart test/page_views_test.dart --reporter expanded: passed, 4 tests.
- lutter test --reporter expanded: passed, all current Flutter tests.
- Focused lutter analyze --no-pub over all changed Dart files: passed with no issues.
- Full lutter analyze: completed with exit code 1 because five existing info-level diagnostics remain in untouched files (onReorder deprecations, QR controller disposal, and one unnecessary import); no errors were reported.
- dart format over changed Dart files: passed.
- git diff --check: passed.
- lutter build windows --release: passed and produced simple_live_app/build/windows/x64/runner/Release/simple_live_app.exe; only an existing third-party WebView CMake development warning was emitted.

### Notes

- simple_live_app/lib/app/controller/base_controller.dart: changed shared scroll-to-top easing.
- simple_live_app/lib/modules/live_room/player/player_controller.dart: removed high-frequency gesture logging.
- simple_live_app/lib/modules/live_room/player/player_controls.dart: unified player control easing and removed duplicate SuperChat wrapper timers.
- simple_live_app/lib/widgets/superchat_card.dart: made the card own one deterministic cancellable countdown timer.
- simple_live_app/test/widget_test.dart: added countdown expiration regression coverage.
- docs/ui-performance-audit.md: records audit scope, implemented changes, deliberate boundaries, and profile gates.
- docs/project-structure.md: records package and module responsibilities.
- progress.md: records this task and its verification evidence.
- Rollback: after committing this task, use git revert <commit>; before committing, reverse only the five scoped source/test files and the two new documents, preserving the pre-existing progress.md changes.

### Correction to the preceding audit record

The command names in the preceding entry are intended to be read as plain text: `flutter test`, `flutter analyze`, and `flutter build windows --release`. A PowerShell quoting artifact rendered the first character of those words as a control character in that appended block; no source file or verification result was affected.
## 2026-08-22 - Task: Fix Windows fullscreen layout synchronization

### What was done

- Fixed desktop fullscreen state synchronization: WindowUtils still handles the Windows maximize/unmaximize workaround, but PlayerController now updates fullScreenState only at the native transition boundary and guards against overlapping enter/exit.
- Unified system-triggered exits (ESC and mouse side button) through exitFullScreenFromSystem, which routes through LiveRoomController when active so the window state and player layout are restored together. Added isFullScreenActive to handle the case where Windows has already left native fullscreen before Flutter receives the key event.
- Fixed Windows-only MissingPluginException from Floating PiP cancelOnLeavePiP during player cleanup by guarding it to Android/iOS.
- Kept earlier audit changes: player control easing (easeOutCubic 200ms), scroll-to-top easing, single-timer SuperChat countdown, and removal of per-pointer gesture logging.

### Testing

- flutter analyze --no-pub lib/main.dart lib/app/utils/window_utils.dart lib/modules/live_room/player/player_controller.dart lib/modules/live_room/live_room_page.dart: No issues found.
- flutter test --reporter expanded: passed, 4 tests.
- flutter build windows --release: passed (third verified build).
- Attempted visible window-size flash elimination was reverted after manual verification showed it broke maximized-window fullscreen (misaligned maximized window). Current build preserves correct maximized restore at the cost of a brief native window-size transition. User confirmed the remaining flash is acceptable and requested stop.

### Notes

- simple_live_app/lib/main.dart: added exitFullScreenFromSystem and isFullScreenActive and routed ESC/side-button through them.
- simple_live_app/lib/app/utils/window_utils.dart: kept maximize workaround but added onTransitionStarted callback to align layout switching.
- simple_live_app/lib/modules/live_room/player/player_controller.dart: added transition guard, aligned fullScreenState with native window callbacks, and guarded PiP cleanup.
- docs/ui-performance-audit.md: documented the attempted flash elimination and its revert.
- progress.md: records this task.
- Rollback: revert this commit with git revert <commit>; for the fullscreen part, revert lib/main.dart, lib/app/utils/window_utils.dart, and lib/modules/live_room/player/player_controller.dart to the state before this task.
## 2026-08-22 - Task: Publish v1.11.9-fix to GitHub

### What was done

- Committed audit and fullscreen fixes (c2f8af8) and fast-forwarded legacy/master from 8baa65a to c2f8af8, pushing to https://github.com/UranusNo7/dart_simple_live.git.
- Created and pushed tag v1.11.9-fix, triggering workflow publish_app_release.yml (app-build-action) which builds Windows and Android artifacts in CI.
- Verified the workflow run 32583571523 completed successfully and GitHub Release v1.11.9-fix was published with 4 assets.

### Testing

- gh run view 32583571523 --repo UranusNo7/dart_simple_live: status completed, conclusion success.
- gh release view v1.11.9-fix --repo UranusNo7/dart_simple_live: 4 assets present (simple_live_app-v1.11.9-fix-windows.zip, app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk), isDraft false, isPrerelease false.
- Local checks before push: flutter analyze --no-pub on changed files No issues found, flutter test 4 passed, flutter build windows --release passed.

### Notes

- Tag v1.11.9-fix points at c2f8af8 on master/migration/win-fullscreen-fix.
- Release URL: https://github.com/UranusNo7/dart_simple_live/releases/tag/v1.11.9-fix
- Rollback: delete remote tag v1.11.9-fix and release, then reset legacy/master to 8baa65a with git push --force-with-lease; revert commit c2f8af8 locally with git revert c2f8af8 if needed.

