import 'package:flutter_test/flutter_test.dart';
import 'package:activity_network/core/routing/route_planning_service.dart';

void main() {
  test('decodes Valhalla polyline6 geometry', () {
    const encoded = 'ejxt~AgahvLc@iLj@sIdW~ZtLpNfHbIhFzFrF`BlAkDp@aEmHsr@yAiQm@cG';
    final points = decodeValhallaPolyline6(encoded);
    expect(points.length, greaterThan(2));
    expect(points.every((p) => p.latitude.isFinite && p.longitude.isFinite), isTrue);
  });
}
