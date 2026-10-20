import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/state/itinerary_presentation.dart';
void main() {
  test('PDF omits equal or dearer days and ordinary-ticket-only days', () {
    final pass = {'id': 'metro', 'name': '도쿄 패스'};
    final result = itineraryPdfPassDays({'dailyCosts': [
      {'day':1, 'regularFareYen':800, 'optimalFareYen':700, 'passes':[pass]},
      {'day':2, 'regularFareYen':700, 'optimalFareYen':700, 'passes':[pass]},
      {'day':3, 'regularFareYen':500, 'optimalFareYen':700, 'passes':[pass]},
      {'day':4, 'regularFareYen':800, 'optimalFareYen':700, 'passes':[]},
    ]});
    expect(result.map((d)=>d['day']).toList(), [1]);
  });
  test('a beneficial continuous pass stays in PDF even if its purchase day is expensive', () {
    final pass = {'id':'jr', 'name':'연속 3일권', 'day':1, 'validUntilDay':3, 'regularFareYen':12000, 'passFareYen':9000, 'savingYen':3000};
    final costs = {'dailyCosts': [
      {'day':1, 'regularFareYen':4000, 'optimalFareYen':9000, 'passes':[pass]},
      {'day':2, 'regularFareYen':4000, 'optimalFareYen':0, 'passes':[pass]},
      {'day':3, 'regularFareYen':4000, 'optimalFareYen':0, 'passes':[pass]},
    ], 'recommendations':[pass, pass, {...pass, 'id':'bad', 'savingYen':0}]};
    expect(itineraryPdfPassDays(costs).map((d)=>d['day']).toList(),[2,3]);
    expect(itineraryPdfPassRecommendations(costs),[pass]);
    expect(itineraryPdfPassRecommendations(null),isEmpty);
  });
}
