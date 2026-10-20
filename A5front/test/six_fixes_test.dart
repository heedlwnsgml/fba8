import 'package:flutter_test/flutter_test.dart';
import 'package:ai_travel_planner/core/network/planner_api.dart';
import 'package:ai_travel_planner/core/state/city_ordering.dart';

class AdminViewApi extends PlannerApi {
  @override
  bool get isAdmin => true;
}

void main() {
  test('제목에 도시가 없으면 첫 선택 도시를 기준으로 정렬한다', () {
    expect(itineraryAnchorCity('', ['도쿄', '가마쿠라'], ['도쿄']), '도쿄');
    expect(itineraryAnchorCity('여름 여행', ['도쿄', '가마쿠라'], ['도쿄']), '도쿄');
    expect(itineraryAnchorCity('가마쿠라 여행', ['도쿄', '가마쿠라'], ['도쿄']), '가마쿠라');
  });
  test('관리자 보기 전환은 표시만 바꾸며 관리자 자격을 바꾸지 않는다', () {
    final api = AdminViewApi();
    expect(api.showAdminInformation, isTrue);
    api.setViewAsUser(true);
    expect(api.showAdminInformation, isFalse);
    expect(api.isAdmin, isTrue);
    api.setViewAsUser(false);
    expect(api.showAdminInformation, isTrue);
    api.logout();
    expect(api.viewAsUser, isFalse);
  });
  test('일반 사용자에게 관리자 표시 전환 권한을 주지 않는다', () {
    final api = PlannerApi();
    api.setViewAsUser(true);
    expect(api.showAdminInformation, isFalse);
    expect(api.viewAsUser, isFalse);
  });
}
