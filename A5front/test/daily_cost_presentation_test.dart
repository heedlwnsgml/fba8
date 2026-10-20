import 'package:flutter_test/flutter_test.dart';
import '../lib/core/state/itinerary_presentation.dart';

void main() {
  test(
    'daily costs include pass names and purchase cost only on purchase day',
    () {
      final text = itineraryDailyCostText({
        'day': 2,
        'optimalFareYen': 3000,
        'regularFareYen': 4200,
        'passPurchaseFareYen': 2000,
        'unknownLegCount': 1,
        'passes': [
          {'name': '도쿄 패스'},
        ],
      });
      expect(text, contains('2일차 - ¥3000'));
      expect(text, contains('패스 적용 대상: 2일차 - 도쿄 패스'));
      expect(text, contains('패스 구매 ¥2000 포함'));
      expect(text, contains('요금 미확인 1구간 별도'));
      expect(
        itineraryDailyCostText({
          'day': 3,
          'optimalFareYen': 0,
          'regularFareYen': 3000,
          'passes': [
            {'name': 'JR 7일권'},
          ],
        }),
        isNot(contains('패스 구매')),
      );
    },
  );
}
