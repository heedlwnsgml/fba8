import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';

void main() {
  const days = '월요일, 화요일, 수요일, 목요일, 금요일, 토요일, 일요일';
  test(
    'Every weekday is compacted but a single day 24-hour opening is not generalized',
    () {
      expect(
        itineraryDescription({
          'openingDays': days,
          'openingHours': '화요일: 오전 10:00 ~ 오후 9:00',
        }),
        contains('휴무일: 없음'),
      );
      expect(
        itineraryDescription({
          'openingDays': days,
          'openingHours': '화요일: 24시간 영업',
        }),
        isNot(contains('매일(24시간)')),
      );
      expect(
        itineraryDescription({'openingDays': '월요일, 수요일'}),
        contains('휴무일: 화요일, 목요일, 금요일, 토요일, 일요일'),
      );
    },
  );
  test('Seven 24-hour days become one compact daily label', () {
    final text = itineraryDescription({
      'openingDays': days,
      'openingHours': days.split(', ').map((d) => '$d: 24시간 영업').join('\n'),
    });
    expect(text, '영업시간: 매주 24시간 영업\n휴무일: 없음');
    expect(
      itineraryDescription({'openingDays': days, 'openingHours': '24시간 영업'}),
      '영업시간: 매주 24시간 영업\n휴무일: 없음 (매일 24시간)',
    );
  });
  test(
    'All seven documented hours supply opening days, single hours do not',
    () {
      expect(
        itineraryOpeningDays(
          '',
          days.split(', ').map((d) => '$d: 24시간 영업').join('\n'),
        ),
        '매일(24시간)',
      );
      expect(itineraryOpeningDays('', '화요일: 24시간 영업'), '');
      expect(itineraryOpeningDays('Monday, Wednesday, Friday', ''), '월,수,금');
      expect(itineraryShortWeekdays('화요일: 10:00 ~ 21:00'), '화: 10:00 ~ 21:00');
    },
  );
}
