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
