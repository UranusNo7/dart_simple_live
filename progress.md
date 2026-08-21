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
