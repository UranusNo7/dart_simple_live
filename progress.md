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
