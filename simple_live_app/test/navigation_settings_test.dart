import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';

void main() {
  test('primary navigation keeps only the three supported destinations', () {
    expect(
      Constant.allHomePages.keys,
      orderedEquals(['recommend', 'follow', 'user']),
    );
    expect(Constant.allHomePages['user']!.index, 2);
  });
}
