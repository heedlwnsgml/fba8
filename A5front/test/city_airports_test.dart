import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/city_airports.dart';

void main() {
  test('도쿄와 가마쿠라에는 수도권 연결 공항만 표시한다', () {
    expect(CityAirports.forCities(['도쿄', '가마쿠라']), {'하네다공항', '나리타국제공항'});
  });
  test('여러 도시의 공항은 중복 없이 합친다', () {
    expect(CityAirports.forCities(['도쿄', '삿포로']), {'하네다공항', '나리타국제공항', '신치토세공항'});
  });
  test('미등록 도시에 임의의 공항을 연결하지 않는다', () {
    expect(CityAirports.forCities(['미등록 도시']), isEmpty);
  });
}
