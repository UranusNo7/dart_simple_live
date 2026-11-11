import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';

void main() {
  test('full login cookies are preserved regardless of cookie order', () {
    const cookies = [
      'sessionid=test-session; ttwid=test-visitor',
      'ttwid=test-visitor; sessionid=test-session',
      'sessionid=test-session',
    ];
    for (final cookie in cookies) {
      expect(AccountController.normalizeDouyinCookieInput(' $cookie '), cookie);
    }
  });

  test('legacy bare ttwid values remain supported', () {
    expect(
      AccountController.normalizeDouyinCookieInput(' 1%7Ctest-visitor '),
      'ttwid=1%7Ctest-visitor',
    );
    expect(
      AccountController.normalizeDouyinCookieInput('ttwid=1%7Ctest-visitor'),
      'ttwid=1%7Ctest-visitor',
    );
  });

  test('empty input keeps the default-cookie path', () {
    expect(AccountController.normalizeDouyinCookieInput(' \n '), isEmpty);
  });
}
