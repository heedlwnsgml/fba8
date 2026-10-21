/// Labels are presentation only. Requests always keep the original city name.
const islandCityNames = <String, String>{
  '나하': '오키나와섬',
  '나고': '오키나와섬',
  '오키나와': '오키나와섬',
  '이시가키': '이시가키섬',
  '미야코지마': '미야코섬',
  '사도': '사도섬',
  '사도시': '사도섬',
  '야쿠시마': '야쿠섬',
  '아마미': '아마미섬',
  '오가사와라': '오가사와라 제도',
};

String islandCityLabel(String city, {bool admin = false}) =>
    admin && islandCityNames.containsKey(city) ? '$city (섬)' : city;

const islandTravelNotice =
    '섬 표시는 다른 섬이나 본토에서 갈 때 비행기·배 이동이 필요한 지역입니다. '
    '섬 사이 구간은 비행기 이동 필요로 표시하고 예상 이동 시간을 계산합니다. 항공편은 별도로 확인해주세요.';
