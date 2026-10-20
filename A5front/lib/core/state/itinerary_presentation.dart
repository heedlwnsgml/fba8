/// Adapt the current backend's DB route DTO without losing per-ride times.
Map<String, dynamic> itineraryNormalizePlace(Map place) {
  final result = Map<String, dynamic>.from(place);
  if (result['transportFromPrevious'] is Map) return result;
  final transit = result['transit'];
  if (transit is! Map) return result;
  result['transportFromPrevious'] = {
    ...Map<String, dynamic>.from(transit),
    'durationMinutes': transit['minutes'] ?? transit['durationMinutes'],
    'steps': [
      for (final step in (transit['steps'] as List? ?? []).whereType<Map>())
        {
          ...Map<String, dynamic>.from(step),
          'mode': step['type'] == '승차'
              ? step['category'] ?? transit['mode']
              : step['type'] ?? step['mode'],
          'lineName': step['line'] ?? step['lineName'] ?? '',
          'durationMinutes': step['minutes'] ?? step['durationMinutes'],
        },
    ],
  };
  return result;
}

String _itineraryValue(Map place, String key, [String? alternative]) =>
    (place[key] ?? (alternative == null ? null : place[alternative]))
        ?.toString()
        .trim() ??
    '';

String itineraryStayDuration(Map place) {
  int? minute(String key) {
    final match = RegExp(
      r'^(\d{2}):(\d{2})$',
    ).firstMatch(_itineraryValue(place, key));
    if (match == null) return null;
    final hour = int.parse(match[1]!), min = int.parse(match[2]!);
    return hour < 24 && min < 60 ? hour * 60 + min : null;
  }

  final start = minute('time'),
      end = minute(
        place['_displayEndTime'] != null ? '_displayEndTime' : 'endTime',
      );
  if (start == null || end == null) return '미확인';
  final duration = end >= start ? end - start : end + 1440 - start;
  return '$duration분';
}

/// Arrival/departure and boarding anchors are not sightseeing stays.
bool itineraryShowStayDuration(Map place) {
  final duration = itineraryStayDuration(place);
  if (!['미확인', '0분'].contains(duration)) return true;
  final category = _itineraryValue(place, 'category');
  final name = _itineraryValue(place, 'placeName');
  return place['_hideEmptyStartFields'] != true &&
      !RegExp(r'숙소|숙박|교통|공항').hasMatch(category) &&
      !RegExp(r'숙소\s*(출발|도착)|공항\s*(도착|출발)|입국|출국').hasMatch(name);
}

/// Mark only the first stop of each day as a lodging departure.
/// The timeline must already be sorted by day and visit order.
void itineraryMarkLodgingDepartures(List<Map<String, dynamic>> timeline) {
  final seenDays = <int>{};
  for (final place in timeline) {
    final day = (place['day'] as num?)?.toInt() ?? 0;
    if (!seenDays.add(day)) continue;
    final category = _itineraryValue(place, 'category');
    if (category.contains('숙소') || category.contains('숙박')) {
      place['_hideEmptyStartFields'] = true;
    }
  }
}

/// Copy the outgoing airport access into the airport card without moving or duplicating itinerary stops.
void itineraryAttachAirportAccess(List<Map<String, dynamic>> timeline) {
  for (var i = 0; i + 1 < timeline.length; i++) {
    final airport = timeline[i], next = timeline[i + 1];
    if (!itineraryIsAirport(airport) || airport['day'] != next['day']) continue;
    final access = airport['airportAccess'];
    if (access is Map &&
        access['originQuery'] is String &&
        access['destinationQuery'] is String) {
      airport['_airportAccessText'] = [
        '${airport['placeName']} → ${access['boardingName']}',
        if (access['walkMinutes'] is num) '도보 약 ${access['walkMinutes']}분',
        if (access['line'] != null) '${access['line']} 탑승',
        if (access['notice'] != null) '${access['notice']}',
      ].join('\n');
      airport['_airportAccessUrl'] = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${access['originQuery']}',
        'destination': '${access['destinationQuery']}',
        'travelmode': 'walking',
      });
      continue;
    }
    final leg = itineraryNormalizePlace(next)['transportFromPrevious'];
    final explicit =
        '${next['placeId'] ?? ''}'.startsWith('airport-access:') ||
        next['subType'] == '공항 승차 지점';
    String station = explicit ? _itineraryValue(next, 'placeName') : '';
    int? minutes;
    String line = '';
    if (leg is Map) {
      if (explicit && leg['mode'] == '도보')
        minutes = (leg['durationMinutes'] as num?)?.toInt();
      final steps = (leg['steps'] as List? ?? []).whereType<Map>();
      var walk = 0;
      for (final step in steps) {
        final mode = '${step['mode'] ?? step['type'] ?? ''}';
        if (mode == '도보' || mode.toLowerCase() == 'walking') {
          walk += ((step['durationMinutes'] ?? step['minutes']) as num? ?? 0)
              .toInt();
        } else if (mode != '대기' && mode != '환승') {
          if (station.isEmpty) station = '${step['from'] ?? ''}'.trim();
          line = '${step['lineName'] ?? step['line'] ?? ''}'.trim();
          if (walk > 0) minutes = walk;
          break;
        }
      }
      if (explicit && minutes == null)
        minutes = (leg['durationMinutes'] as num?)?.toInt();
    }
    if (station.isEmpty) continue;
    airport['_airportAccessText'] = [
      '${airport['placeName']} → $station',
      if (minutes != null) '도보 약 ${minutes < 3 ? 3 : minutes}분',
      if (line.isNotEmpty) '$line 탑승',
    ].join('\n');
    final originalStation = leg is Map
        ? (leg['steps'] as List? ?? [])
              .whereType<Map>()
              .where((s) => !['도보', '대기', '환승'].contains(s['mode']))
              .firstOrNull
        : null;
    final scopedStation =
        '${originalStation?['fromOriginal'] ?? station} 日本 ${airport['placeName']}';
    final origin = '$scopedStation 到着ロビー';
    final destination =
        explicit && next['latitude'] is num && next['longitude'] is num
        ? '${next['latitude']},${next['longitude']}'
        : scopedStation;
    if (airport['latitude'] is num && airport['longitude'] is num) {
      airport['_airportAccessUrl'] = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': origin,
        'destination': destination,
        'travelmode': 'walking',
      });
    }
  }
}

/// Keep incoming legs for schedule calculations; attach outgoing legs for presentation only.
void itineraryAttachOutgoingLegs(List<Map<String, dynamic>> timeline) {
  for (var i = 0; i < timeline.length; i++) {
    final current = timeline[i];
    current.remove('_transportToNext');
    current.remove('_nextPlaceName');
    if (i + 1 >= timeline.length || current['day'] != timeline[i + 1]['day'])
      continue;
    final next = timeline[i + 1];
    final leg = itineraryNormalizePlace(next)['transportFromPrevious'];
    current['_nextPlaceName'] = next['placeName'];
    if (leg is Map)
      current['_transportToNext'] = Map<String, dynamic>.from(leg);
  }
}

void itineraryAttachLodgingPrices(
  List<Map<String, dynamic>> timeline,
  List<Map> lodgings,
) {
  String normalized(Object? value) =>
      '${value ?? ''}'.replaceAll(RegExp(r'\s*[(（]?숙소\s*(출발|도착).*'), '').trim();
  for (final place in timeline) {
    if (!RegExp(r'숙소|숙박|료칸|여관').hasMatch('${place['category']}')) continue;
    final day = (place['day'] as num?)?.toInt() ?? 0;
    final matches = lodgings.where((stay) {
      final id = '${place['placeId'] ?? ''}',
          other = '${stay['placeId'] ?? ''}';
      final same = id.isNotEmpty && other.isNotEmpty
          ? id == other
          : normalized(place['placeName']) == normalized(stay['name']);
      return same &&
          day >= ((stay['checkInDay'] as num?)?.toInt() ?? 1) &&
          day <= ((stay['checkOutDay'] as num?)?.toInt() ?? day);
    });
    final quote = matches.firstOrNull;
    if (quote?['priceComparisons'] is List)
      place['hotelPriceComparisons'] = quote!['priceComparisons'];
    if (quote?['lowestNightPerRoomYen'] is num)
      place['lowestNightPerRoomYen'] = quote!['lowestNightPerRoomYen'];
  }
}

String itineraryPlaceInformation(Map place, {bool admin = false}) {
  String available(String text) =>
      text.isEmpty || text.contains('정보 없음') ? '정보 없음' : text;
  return [
    if (itineraryShowStayDuration(place))
      '체류시간: ${itineraryStayDuration(place)}',
    if (place['diningType'] != null)
      '식사 장소 유형: ${itineraryDiningLabel(place['diningType'])}',
    if ((place['hotelPriceComparisons'] as List? ?? []).isNotEmpty)
      '숙박요금 비교: ${(place['hotelPriceComparisons'] as List).whereType<Map>().map((q) => '${q['provider']} · 1박 약 ¥${q['yen']}\n${q['url']}').join('\n\n')}',
    if (place['lowestNightPerRoomYen'] is num)
      '숙박비: ¥${place['lowestNightPerRoomYen']}',
    if (place['lowestNightPerRoomYen'] == null &&
        (_itineraryValue(place, 'category').contains('숙소') ||
            _itineraryValue(place, 'category').contains('숙박')) &&
        place['averageHotelPriceYen'] == null)
      '평균 숙박요금: 자료 없음 · 숙소 예산 충족 여부 미확인',
    if (place['lowestNightPerRoomYen'] == null &&
        place['averageHotelPriceYen'] is num)
      '숙박비: ¥${place['averageHotelPriceYen']}',
    if (_itineraryValue(place, '_airportAccessText').isNotEmpty)
      '공항 내 이동: ${place['_airportAccessText']}',
    '주소: ${available(_itineraryValue(place, 'address', 'formattedAddress'))}',
    '전화번호: ${available(_itineraryValue(place, 'phoneNumber'))}',
    '영업시간: ${available(itineraryBusinessHours(place))}',
    if (place['_visitWeekday'] is! int) '영업일: ${itineraryBusinessDays(place)}',
  ].join('\n');
}

bool itineraryDriving(Object? mode) => RegExp(
  r'자동차|차량|렌트|렌터|car|driving',
  caseSensitive: false,
).hasMatch(mode?.toString() ?? '');

bool _lodgingDeparture(String text) {
  final value = text.trim().replaceFirst(RegExp(r'^설명:\s*'), '');
  return RegExp(r'^숙소\s*출발[.!]?$').hasMatch(value) ||
      value == '숙소 도착 및 휴식' ||
      value == '여행 중 머무는 숙소' ||
      value.contains('하루 일정 후 휴식하고 다음 날 여행을 시작하는 거점') ||
      value.contains('토요코인의 기본적인 숙박 서비스와 조식을 제공합니다');
}

String itineraryPlaceExplanation(Map place) {
  if (itineraryIsAirport(place)) {
    final known = ['summary', 'briefDescription', 'description']
        .map((key) => _itineraryValue(place, key))
        .where(
          (text) =>
              RegExp(r'[가-힣]').hasMatch(text) &&
              !_lodgingDeparture(text) &&
              !text.startsWith('사용자가 지정한'),
        )
        .firstOrNull;
    return '설명: ${known ?? '입국 수속과 수하물 수령을 마친 후 터미널의 철도·버스 안내 표지를 따라 승차 지점으로 이동하세요.'}';
  }
  final descriptions = <String>[];
  for (final key in ['briefDescription', 'description', 'summary']) {
    final text = _itineraryValue(place, key);
    if (text.isNotEmpty &&
        !_lodgingDeparture(text) &&
        !_themeOnly(text) &&
        !descriptions.contains(text) &&
        !text.startsWith('사용자가 지정한 입') &&
        !text.startsWith('사용자가 지정한 출')) {
      descriptions.add(text);
    }
  }
  if (descriptions.isEmpty &&
      (_itineraryValue(place, 'category').contains('숙소') ||
          _itineraryValue(place, 'category').contains('숙박')))
    return '';
  if (descriptions.isEmpty &&
      [
        'briefDescription',
        'description',
        'summary',
      ].any((key) => _lodgingDeparture(_itineraryValue(place, key))))
    return '';
  final diningGuide = _itineraryValue(place, 'diningGuide');
  if (diningGuide.isNotEmpty && !descriptions.contains(diningGuide))
    descriptions.add(diningGuide);
  return '설명: ${descriptions.isEmpty ? '정보 없음' : descriptions.join('\n')}';
}

String itineraryClosedDays(String days, String hours) {
  if (itineraryOpenEveryDay(days))
    return itineraryOpenAllDay(hours) ? '없음 (매일 24시간)' : '없음';
  const names = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  const aliases = [
    ['월요일', 'monday', 'mon', '月曜日'],
    ['화요일', 'tuesday', 'tue', '火曜日'],
    ['수요일', 'wednesday', 'wed', '水曜日'],
    ['목요일', 'thursday', 'thu', '木曜日'],
    ['금요일', 'friday', 'fri', '金曜日'],
    ['토요일', 'saturday', 'sat', '土曜日'],
    ['일요일', 'sunday', 'sun', '日曜日'],
  ];
  final lower = days.toLowerCase();
  final open = [
    for (int i = 0; i < 7; i++)
      if (aliases[i].any((a) => lower.contains(a))) i,
  ];
  if (open.isEmpty ||
      RegExp(r'휴무|정기휴일|closed|불규칙|공휴일', caseSensitive: false).hasMatch(days))
    return '확인 필요';
  return [
    for (int i = 0; i < 7; i++)
      if (!open.contains(i)) names[i],
  ].join(', ');
}

String itineraryOpeningDays(String days, String hours) {
  if (itineraryOpenEveryDay(days) || itineraryOpenEveryDay(hours))
    return itineraryOpenAllDay(hours) ? '매일(24시간)' : '매일';
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  const aliases = [
    ['월요일', 'monday', 'mon', '月曜日'],
    ['화요일', 'tuesday', 'tue', '火曜日'],
    ['수요일', 'wednesday', 'wed', '水曜日'],
    ['목요일', 'thursday', 'thu', '木曜日'],
    ['금요일', 'friday', 'fri', '金曜日'],
    ['토요일', 'saturday', 'sat', '土曜日'],
    ['일요일', 'sunday', 'sun', '日曜日'],
  ];
  final lower = days.toLowerCase();
  final found = [
    for (int i = 0; i < 7; i++)
      if (aliases[i].any(lower.contains)) labels[i],
  ];
  if (found.isNotEmpty &&
      !RegExp(r'휴무|closed|정기휴일', caseSensitive: false).hasMatch(days))
    return found.join(',');
  return days.replaceAll('요일', '');
}

String itineraryShortWeekdays(String value) => value.replaceAll('요일', '');

bool itineraryOpenEveryDay(String days) {
  const groups = [
    ['월요일', 'monday', 'mon', '月曜日'],
    ['화요일', 'tuesday', 'tue', '火曜日'],
    ['수요일', 'wednesday', 'wed', '水曜日'],
    ['목요일', 'thursday', 'thu', '木曜日'],
    ['금요일', 'friday', 'fri', '金曜日'],
    ['토요일', 'saturday', 'sat', '土曜日'],
    ['일요일', 'sunday', 'sun', '日曜日'],
  ];
  final lower = days.toLowerCase();
  return lower == '매일' ||
      lower == '매일(24시간)' ||
      groups.every((g) => g.any((v) => lower.contains(v)));
}

bool itineraryOpenAllDay(String hours) {
  final daily = RegExp(
    r'매일|every day|daily',
    caseSensitive: false,
  ).hasMatch(hours);
  final matches = RegExp(
    r'24시간|24 hours|open 24|00:00\s*[~–-]\s*24:00',
    caseSensitive: false,
  ).allMatches(hours).length;
  return matches >= 7 ||
      (matches > 0 &&
          (daily ||
              !RegExp(r'요일|day:|曜日', caseSensitive: false).hasMatch(hours)));
}

bool _themeOnly(String text) {
  if (text == '추천 일정') return true;
  if (!text.endsWith(' 일정')) return false;
  const themes = {
    '관광',
    '문화',
    '자연',
    '힐링',
    '사진',
    '야경',
    '쇼핑',
    '맛집',
    '카페',
    '액티비티',
    '서브컬쳐',
    '서브컬처',
    '테마파크',
    '식도락',
  };
  final parts = text.substring(0, text.length - 3).split(RegExp(r'[,·/]'));
  return parts.isNotEmpty &&
      parts.every((part) => themes.contains(part.trim()));
}

bool itineraryUnverifiedTransport(Map leg) {
  if (leg['source'] == 'domestic-flight-fare' || leg['source'] == 'taxi')
    return false;
  final mode = leg['mode']?.toString() ?? '';
  if (mode == '도보' || mode == '자동차') return false;
  return !(leg['steps'] as List? ?? []).whereType<Map>().any(
    (s) =>
        !['도보', '대기', '대기·환승'].contains(s['mode']) &&
        (s['lineName']?.toString().trim().isNotEmpty ?? false),
  );
}

String itineraryKoreanTransport(String text) {
  const replacements = {
    '高速バス': '고속버스',
    '路線バス': '시내버스',
    'リムジンバス': '리무진 버스',
    'シャトルバス': '셔틀버스',
    'コミュニティバス': '지역버스',
    '空港バス': '공항버스',
    'バス': '버스',
    '都営': '도영',
    '市営': '시영',
    '急行': '급행',
    '各駅停車': '일반',
    '電車': '전철',
    '鉄道': '철도',
    '地下鉄': '지하철',
  };
  for (final e in replacements.entries) {
    text = text.replaceAll(e.key, e.value);
  }
  // Unknown Japanese proper names stay in detailed information, not the short Korean field.
  if (RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').hasMatch(text))
    return text.contains('버스')
        ? '버스'
        : text.contains('지하철')
        ? '지하철'
        : text.contains('철도') || text.contains('전철')
        ? '철도'
        : '대중교통';
  return text;
}

String itineraryTransportSummary(Map leg) {
  final minutes = (leg['durationMinutes'] as num?)?.toInt() ?? 0;
  if (leg['source'] == 'domestic-flight-fare') return '이동: 국내선 약 $minutes분';
  if (leg['source'] == 'taxi') return '이동: 택시 약 $minutes분';
  final steps = (leg['steps'] as List? ?? []).whereType<Map>().toList();
  final rides = steps
      .where(
        (s) =>
            (s['mode'] == '도보' ||
            (!['대기', '대기·환승', '환승'].contains(s['mode']) &&
                (s['lineName']?.toString().trim().isNotEmpty ?? false))),
      )
      .toList();
  if (rides.isNotEmpty && !itineraryUnverifiedTransport(leg)) {
    final parts = rides
        .map((step) {
          var mode = itineraryKoreanTransport(step['mode']?.toString() ?? '');
          if (mode == 'JR') mode = 'JR 철도';
          if (mode.isEmpty || mode == '승차' || mode == '대중교통') {
            final line = itineraryKoreanTransport(
              step['lineName']?.toString() ?? '',
            );
            mode = line.contains('버스')
                ? '버스'
                : line.contains('지하철')
                ? '지하철'
                : line.contains('신칸센')
                ? '신칸센'
                : '철도';
          }
          var duration = (step['durationMinutes'] as num?)?.toInt();
          if (mode == '도보' && duration != null && duration < 3) duration = 3;
          return '$mode ${duration == null || duration <= 0 ? '시간 미확인' : '${duration}분'}';
        })
        .join(' → ');
    return '이동: $parts';
  }
  final mode = itineraryKoreanTransport(leg['mode']?.toString() ?? '대중교통');
  if (['distance', 'distance-average'].contains(leg['source']) && minutes > 0) {
    return '이동: ${mode == '자동차' ? mode : '대중교통'} 약 $minutes분';
  }
  if (itineraryUnverifiedTransport(leg)) return '이동: 경로 확인 필요 · 소요시간 미확인';
  if (mode == '도보' && minutes < 3) return '이동: 도보 약 3분';
  return '이동: $mode ${leg['estimated'] == true ? '약 ' : ''}$minutes분';
}

Uri? itineraryDirectionsUrl(
  Map from,
  Map to, {
  bool walking = false,
  bool driving = false,
}) {
  final aLat = (from['latitude'] as num?)?.toDouble(),
      aLon = (from['longitude'] as num?)?.toDouble();
  final bLat = (to['latitude'] as num?)?.toDouble(),
      bLon = (to['longitude'] as num?)?.toDouble();
  if (!validItineraryLocation(aLat, aLon) ||
      !validItineraryLocation(bLat, bLon))
    return null;
  if (aLat == bLat && aLon == bLon) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '$aLat,$aLon',
    'destination': '$bLat,$bLon',
    'travelmode': walking
        ? 'walking'
        : driving
        ? 'driving'
        : 'transit',
  });
}

String itineraryDescription(Map<String, dynamic> place) {
  final lines = <String>[];
  final leg = itineraryNormalizePlace(place)['transportFromPrevious'];
  if (leg is Map &&
      leg['durationMinutes'] is num &&
      (leg['durationMinutes'] as num) >= 0) {
    lines.add(itineraryTransportSummary(leg));
    for (final step
        in (itineraryUnverifiedTransport(leg)
                ? <dynamic>[]
                : leg['steps'] as List? ?? [])
            .whereType<Map>()) {
      final mode = step['mode']?.toString() ?? '';
      final line = step['lineName']?.toString() ?? '';
      final from = step['from']?.toString() ?? '';
      final to = step['to']?.toString() ?? '';
      final sameStation =
          from.replaceAll(RegExp(r'\s+'), '') ==
          to.replaceAll(RegExp(r'\s+'), '');
      final stops =
          from.isNotEmpty &&
              to.isNotEmpty &&
              !(sameStation && RegExp(r'대기|환승').hasMatch(mode))
          ? ' · $from → $to'
          : '';
      if ((step['durationMinutes'] as num? ?? 0) <= 0) continue;
      lines.add(
        '${line.isEmpty ? mode : '$mode · $line'}$stops · ${mode.contains('대기') ? '약 ' : ''}${step['durationMinutes']}분',
      );
    }
  }
  if (leg is Map &&
      (leg['durationMinutes'] as num? ?? 0) > 0 &&
      leg['mode'] != '도보') {
    final fare = leg['fareYen'];
    final average =
        ['distance', 'distance-average'].contains(leg['source']) ||
        (leg['fareNote']?.toString().startsWith('거리 기준 평균') ?? false);
    if (fare is num || !itineraryDriving(leg['mode']))
      lines.add(
        fare is num
            ? '교통비: 성인 1인 ${average || leg['source'] == 'domestic-flight-fare' ? '약 ' : ''}¥${fare.toInt()}'
            : '교통비: 요금 미확인',
      );

    if (itineraryUnverifiedTransport(leg) && !average)
      lines.add('이동 경로가 확인되지 않아 일정 시각은 임시 배치입니다.');
    if (leg['source'] == 'domestic-flight-fare' && leg['lineId'] != null)
      lines.add('항공 구간: ${leg['lineId']}');
    if (leg['source'] == 'google-routes-transit')
      lines.add('Google 지도 · 출발 시각 기준 경로 / 운행 변경 가능');
    if (leg['source'] == 'official-gtfs')
      lines.add(leg['fareNote']?.toString() ?? '공식 GTFS 시간표 / 도보는 근사값·지연 미반영');
    if (leg['source'] == 'official-bus-timetable')
      lines.add(leg['fareNote']?.toString() ?? '공식 버스 시간표·요금 / 도보·정류장 위치는 근사값');
    if (leg['source'] == 'gemini-grounded-transit')
      lines.add(leg['fareNote']?.toString() ?? '공식 검색 근거로 보완한 요금·평균 이동 시간');
    if (leg['source'] == 'official-catalog')
      lines.add('공식 역간 노선·요금 / 도보·대기는 추정');
  }
  if (leg is Map &&
      (!itineraryUnverifiedTransport(leg) ||
          ['distance', 'distance-average'].contains(leg['source'])) &&
      (leg['durationMinutes'] as num? ?? 0) > 0) {
    final minutes = (leg['durationMinutes'] as num).toInt();
    lines.add(
      '총 이동 시간: 약 ${leg['mode'] == '도보' && minutes < 3 ? 3 : minutes}분',
    );
  }
  final end = (place['_displayEndTime'] ?? place['endTime'])?.toString() ?? '';
  if (end.isNotEmpty && end != place['time'])
    lines.add('시간: ${place['time']} ~ $end');
  final waiting = (place['waitingMinutes'] as num?)?.toInt() ?? 0;
  if (waiting >= 15) lines.add('일정 사이 대기 및 휴식: 약 $waiting분');
  for (final key in ['briefDescription', 'description', 'summary']) {
    final value = place[key]?.toString().trim() ?? '';
    if (value.isNotEmpty &&
        !value.startsWith('사용자가 지정한 입') &&
        !value.startsWith('사용자가 지정한 출') &&
        !_lodgingDeparture(value) &&
        !_themeOnly(value) &&
        !lines.contains(value))
      lines.add(value);
  }
  for (final entry in {'address': '주소', 'phoneNumber': '전화번호'}.entries) {
    final value = _itineraryValue(
      place,
      entry.key,
      entry.key == 'address' ? 'formattedAddress' : null,
    );
    if (value.isNotEmpty && !value.contains('정보 없음'))
      lines.add('${entry.value}: $value');
  }
  if ([
    'openingHours',
    'weeklyOpeningHours',
    'openingDays',
  ].any((key) => _itineraryValue(place, key).isNotEmpty)) {
    final hours = itineraryBusinessHours(place);
    if (hours.isNotEmpty) lines.add('영업시간: $hours');
    if (place['_visitWeekday'] is! int)
      lines.add('휴무일: ${itineraryBusinessClosures(place)}');
  }
  return lines.join('\n');
}

int itineraryOrder(Map place) {
  final text = place['time']?.toString() ?? '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (match != null)
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  final name = place['placeName']?.toString() ?? '';
  if (name.startsWith('입국 ·')) return -1;
  if (name.startsWith('출국 ·')) return 1441;
  return 1440;
}

bool itineraryIsAirport(Map place) {
  if (place['category'] == '공항') return true;
  if ('${place['placeId'] ?? ''}'.startsWith('airport-access:') ||
      place['subType'] == '공항 승차 지점')
    return false;
  final name = '${place['placeName'] ?? ''}';
  return RegExp(r'공항|airport|空港', caseSensitive: false).hasMatch(name) &&
      !RegExp(
        r'역$|버스.*터미널|버스.*정류장|station$',
        caseSensitive: false,
      ).hasMatch(name);
}

String itineraryCategory(Map place) {
  if (itineraryIsAirport(place)) return '공항';
  final rawCategory = place['category']?.toString().trim() ?? '관광지';
  final category = rawCategory.split(RegExp(r'[,/·]')).first.trim();
  if (category != '식음') {
    if (category == '식사' || category == '간식' || category.endsWith('-식사'))
      return category;
    final tags = <String>[
      rawCategory,
      place['theme']?.toString() ?? '',
      ...(place['themes'] is List
          ? (place['themes'] as List).map((t) => t.toString())
          : [place['themes']?.toString() ?? '']),
      place['subType']?.toString() ?? '',
    ].join(',');
    final secondaryMeal = tags
        .split(RegExp(r'[,/·|\s]+'))
        .any(
          (tag) => const {
            '식사',
            '식음',
            '식당',
            '맛집',
            '미식',
            '미식여행',
            '식도락',
            '음식점',
            '라멘',
            '스시',
            '우동',
            '소바',
            '돈카츠',
            'restaurant',
            'meal',
          }.contains(tag.toLowerCase()),
        );
    return secondaryMeal ? '$category-식사' : category;
  }
  final text =
      '${place['placeName'] ?? ''} ${place['theme'] ?? ''} ${place['subType'] ?? ''} ${place['themes'] ?? ''}'
          .toLowerCase();
  return RegExp(
        r'cafe|café|coffee|dessert|bakery|카페|커피|디저트|찻집|스위츠|베이커리|カフェ|珈琲',
      ).hasMatch(text)
      ? '간식'
      : '식사';
}

bool validItineraryLocation(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    (latitude != 0 || longitude != 0);

String itineraryPassPeriod(Map row, DateTime? start) {
  final first = (row['day'] as num?)?.toInt() ?? 1;
  final last =
      (row['validUntilDay'] as num?)?.toInt() ??
      (row['endDay'] as num?)?.toInt() ??
      first;
  String date(int d) {
    final v = start?.add(Duration(days: d - 1));
    return v == null ? '' : '${v.month}/${v.day}';
  }

  final range = last == first ? '$first일차' : '$first~$last일차';
  return '$range${start == null ? '' : ' (${date(first)}${first == last ? '' : '~${date(last)}'})'} · ${row['name']} · ¥${row['passFareYen']}${last > first ? ' · 연속 사용' : ''}';
}

String itineraryDailyCostText(Map day) {
  final index = day['day'];
  final passes = (day['passes'] as List? ?? []).whereType<Map>().toList();
  final names = passes
      .map((p) => p['name'] ?? '')
      .where((n) => n.toString().isNotEmpty)
      .join(' · ');
  final purchase = (day['passPurchaseFareYen'] as num? ?? 0).toInt();
  final unknown = (day['unknownLegCount'] as num? ?? 0).toInt();
  return '${index}일차 - ¥${day['optimalFareYen']} (일반 승차권 ¥${day['regularFareYen']})'
      '${purchase > 0 ? "\n패스 구매 ¥$purchase 포함" : ""}'
      '\n패스 적용 대상: ${index}일차 - ${names.isEmpty ? "일반 승차권" : names}'
      '${unknown > 0 ? "\n요금 미확인 $unknown구간 별도" : ""}';
}

/// A multi-day purchase can cost more on its first day while saving overall.
List<Map> itineraryBeneficialPassDays(Map? costs) {
  final recommendations = itineraryPdfPassRecommendations(costs);
  return (costs?['dailyCosts'] as List? ?? []).whereType<Map>().where((day) {
    final n = (day['day'] as num?)?.toInt();
    final used = (day['passes'] as List? ?? []).whereType<Map>();
    if (n == null || used.isEmpty) return false;
    if (used.any((p) => (p['savingYen'] as num? ?? 0) > 0)) return true;
    if (recommendations.any((p) {
      final first = (p['day'] as num? ?? 1).toInt(),
          last =
              (p['validUntilDay'] as num? ??
                      p['endDay'] as num? ??
                      p['day'] as num? ??
                      1)
                  .toInt();
      return n >= first &&
          n <= last &&
          used.any(
            (u) =>
                (p['id'] != null && u['id'] == p['id']) ||
                (p['name'] != null && u['name'] == p['name']),
          );
    }))
      return true;
    return (day['optimalFareYen'] as num? ?? double.infinity) <
        (day['regularFareYen'] as num? ?? 0);
  }).toList()..sort((a, b) => (a['day'] as num).compareTo(b['day'] as num));
}

List<Map> itineraryPdfPassDays(Map? costs) =>
    (costs?['dailyCosts'] as List? ?? []).whereType<Map>().where((day) {
      final regular = day['regularFareYen'];
      final optimal = day['optimalFareYen'];
      return regular is num &&
          optimal is num &&
          optimal < regular &&
          (day['passes'] as List? ?? []).whereType<Map>().isNotEmpty;
    }).toList();

List<Map> itineraryPdfPassRecommendations(Map? costs) {
  final rows =
      (costs?['recommendations'] as List? ??
              costs?['passComparisons'] as List? ??
              [])
          .whereType<Map>();
  final seen = <String>{};
  return rows.where((row) {
    final regular = row['regularFareYen'];
    final price = row['passFareYen'];
    final saving = row['savingYen'];
    final cheaper = saving is num
        ? saving > 0
        : regular is num && price is num && price < regular;
    return cheaper &&
        seen.add(
          '${row['id'] ?? row['name']}:${row['day']}:${row['validUntilDay']}',
        );
  }).toList();
}

/// The same guidance groups are used on screen and in exported PDFs.
Map<String, List<String>> itineraryGuidance(Object? warnings) {
  final groups = <String, List<String>>{};
  for (final value in warnings is List ? warnings : const []) {
    final text = value.toString().trim();
    if (text.isEmpty ||
        RegExp(
          r'날씨|예보|기상|계절|평년|장마|태풍|폭설|강수|weather|forecast',
          caseSensitive: false,
        ).hasMatch(text))
      continue;
    final title = RegExp(r'숙소|숙박|객실|체크인').hasMatch(text)
        ? '숙소·숙박비'
        : RegExp(r'식사|식당|카페|간식').hasMatch(text)
        ? '식사·간식'
        : RegExp(r'이동|교통|노선|패스|요금|항공|환승').hasMatch(text)
        ? '이동·교통비'
        : RegExp(r'영업|휴무|운영').hasMatch(text)
        ? '영업·방문 확인'
        : RegExp(r'시간|일정|기간|공항|도시|날짜').hasMatch(text)
        ? '일정·시간'
        : '여행 전 확인';
    final items = groups.putIfAbsent(title, () => []);
    if (!items.contains(text)) items.add(text);
  }
  return groups;
}

String itineraryPassSummary(Map? costs) {
  if (costs == null) return '교통 요금 정보가 없습니다.';
  final recommendations = (costs['recommendations'] as List? ?? [])
      .whereType<Map>()
      .where((r) => (r['savingYen'] as num? ?? 0) > 0)
      .toList();
  if (recommendations.isNotEmpty) {
    final names = recommendations
        .map((r) => r['name']?.toString() ?? '교통 패스')
        .toSet()
        .join(' · ');
    return '$names 추천 · 일별 적용 내용은 상세보기에서 확인하세요.';
  }
  if ((costs['unknownLegCount'] as num? ?? 0) > 0) {
    return '확인된 구간은 일반 승차권을 이용하세요. 요금 미확인 구간은 상세보기에서 확인할 수 있습니다.';
  }
  return '일반 승차권이 가장 효율적입니다.';
}

/// Keep the persisted visit duration intact, and expose departure buffer only in
/// presentation. The next stop owns its incoming travel time.
void itineraryIncludeStayBuffer(List<Map<String, dynamic>> timeline) {
  int? minute(Object? value) {
    final m = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(value?.toString() ?? '');
    return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
  }

  for (int i = 0; i + 1 < timeline.length; i++) {
    final place = timeline[i], next = timeline[i + 1];
    if (place['day'] != next['day'] ||
        RegExp(r'숙소|숙박|교통|공항|자유').hasMatch('${place['category']}'))
      continue;
    final start = minute(place['time']),
        end = minute(place['endTime']),
        arrival = minute(next['time']);
    final leg = itineraryNormalizePlace(next)['transportFromPrevious'];
    final travel = leg is Map ? leg['durationMinutes'] : null;
    if (start == null ||
        end == null ||
        arrival == null ||
        travel is! num ||
        travel < 0 ||
        end <= start)
      continue;
    final departure = arrival - travel.toInt();
    if (departure > end && departure < 1440) {
      place['_displayEndTime'] =
          '${(departure ~/ 60).toString().padLeft(2, '0')}:${(departure % 60).toString().padLeft(2, '0')}';
      place['_stayBufferMinutes'] = departure - end;
    }
  }
}

bool itineraryMissingInformation(String text) => RegExp(
  r'미확인|이동 경로가 확인되지|일정 시각은 임시|자료\s*없|자료가\s*없|정보\s*없|정보가\s*없|확인\s*필요|확인할\s*수\s*없|미산정|알\s*수\s*없|계산\s*미완료|비교.*완료.*못|비교가.*완료되지',
).hasMatch(text);

String itineraryVisibleText(String text, {required bool admin}) => admin
    ? text
    : text
          .split('\n')
          .where((line) => !itineraryMissingInformation(line))
          .join('\n')
          .trim();

String itineraryDiningLabel(Object? value) =>
    value?.toString() == '개별 식당' ? '식당' : value?.toString() ?? '';

const _businessDays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
const _businessAliases = [
  ['월요일', '月曜日', 'Monday'],
  ['화요일', '火曜日', 'Tuesday'],
  ['수요일', '水曜日', 'Wednesday'],
  ['목요일', '木曜日', 'Thursday'],
  ['금요일', '金曜日', 'Friday'],
  ['토요일', '土曜日', 'Saturday'],
  ['일요일', '日曜日', 'Sunday'],
];

Map<int, String> itineraryWeeklyHours(Map place) {
  final raw = _itineraryValue(place, 'weeklyOpeningHours').isEmpty
      ? _itineraryValue(place, 'openingHours')
      : _itineraryValue(place, 'weeklyOpeningHours');
  final result = <int, String>{};
  for (final segment in raw.split(RegExp(r'\s*[|\n]\s*'))) {
    for (int i = 0; i < 7; i++) {
      for (final alias in _businessAliases[i]) {
        if (segment.toLowerCase().startsWith(alias.toLowerCase())) {
          result[i] = segment
              .substring(alias.length)
              .replaceFirst(RegExp(r'^\s*[:：]?\s*'), '')
              .trim();
          break;
        }
      }
    }
  }
  return result;
}

bool itineraryTraditionalLodging(Map place) {
  final category = _itineraryValue(place, 'category');
  final text = [
    'placeName',
    'subType',
    'accommodationType',
    'category',
  ].map((key) => _itineraryValue(place, key)).join(' ');
  return RegExp(
        r'료칸|여관|일본\s*전통\s*(숙소|숙박)|전통\s*(숙소|숙박)|ryokan|旅館',
        caseSensitive: false,
      ).hasMatch(text) &&
      (!RegExp(r'식사|식음|맛집|관광|쇼핑|카페').hasMatch(category) ||
          RegExp(
            r'숙소|숙박|료칸|여관|ryokan',
            caseSensitive: false,
          ).hasMatch(category));
}

String itineraryBusinessHours(Map place) {
  if (itineraryTraditionalLodging(place)) return '매주 24시간 영업';
  final weekly = itineraryWeeklyHours(place);
  final visitDay = place['_visitWeekday'];
  if (visitDay is int) {
    if (weekly.containsKey(visitDay))
      return '${_businessDays[visitDay]}: ${weekly[visitDay]}';
    final text = itineraryShortWeekdays(_itineraryValue(place, 'openingHours'));
    return text.replaceFirst(RegExp(r'^매주|^매일'), _businessDays[visitDay]);
  }
  final values = weekly.values
      .where(
        (s) =>
            !RegExp(r'휴무|closed|정기휴일|定休日', caseSensitive: false).hasMatch(s) &&
            s.isNotEmpty,
      )
      .toList();
  if (weekly.length == 7 &&
      values.isNotEmpty &&
      values.map((s) => s.replaceAll(RegExp(r'\s+'), '')).toSet().length == 1) {
    return '매주 ${values.first}';
  }
  final day = place['_visitWeekday'];
  if (day is int && weekly.containsKey(day))
    return '${_businessDays[day]}: ${weekly[day]}';
  if (itineraryOpenAllDay(_itineraryValue(place, 'openingHours')) &&
      itineraryOpenEveryDay(_itineraryValue(place, 'openingDays')))
    return '매주 24시간 영업';
  if (weekly.isNotEmpty) {
    final groups = <String, List<String>>{};
    for (final e
        in weekly.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      if (RegExp(r'휴무|closed|정기휴일|定休日', caseSensitive: false).hasMatch(e.value))
        continue;
      groups
          .putIfAbsent(e.value, () => [])
          .add(_businessDays[e.key].replaceAll('요일', ''));
    }
    if (groups.isNotEmpty)
      return groups.entries
          .map((e) => "${e.value.join(', ')}: ${e.key}")
          .join('\n');
  }
  return itineraryShortWeekdays(_itineraryValue(place, 'openingHours'));
}

String itineraryBusinessDays(Map place) {
  final weekly = itineraryWeeklyHours(place);
  if (weekly.length == 7) {
    final open =
        weekly.entries
            .where(
              (e) =>
                  e.value.trim().isNotEmpty &&
                  !RegExp(
                    r'휴무|closed|정기휴일|定休日',
                    caseSensitive: false,
                  ).hasMatch(e.value),
            )
            .map((e) => e.key)
            .toList()
          ..sort();
    if (open.length == 7) return '매일';
    if (open.isNotEmpty)
      return open
          .map((day) => _businessDays[day].replaceAll('요일', ''))
          .join(', ');
  }
  final supplied = _itineraryValue(place, 'openingDays');
  if (itineraryOpenEveryDay(supplied)) return '매일';
  return supplied.isEmpty ? '확인 필요' : itineraryShortWeekdays(supplied);
}

String itineraryBusinessClosures(Map place) {
  final weekly = itineraryWeeklyHours(place);
  if (weekly.length == 7) {
    final closed = weekly.entries
        .where(
          (e) => RegExp(
            r'휴무|closed|정기휴일|定休日',
            caseSensitive: false,
          ).hasMatch(e.value),
        )
        .map((e) => _businessDays[e.key])
        .toList();
    return closed.isEmpty ? '없음' : closed.join(', ');
  }
  return itineraryClosedDays(
    _itineraryValue(place, 'openingDays'),
    _itineraryValue(place, 'weeklyOpeningHours', 'openingHours'),
  );
}

String itineraryCompactPassDay(Map day) {
  final passes = (day['passes'] as List? ?? []).whereType<Map>().toList();
  final names = passes
      .map((p) {
        final first = (p['day'] as num?)?.toInt(),
            last = (p['validUntilDay'] as num? ?? p['endDay'] as num?)?.toInt();
        return '${p['name'] ?? '교통 패스'}${first != null && last != null && last > first ? ' ($first~$last일차 연속 사용)' : ''}';
      })
      .toSet()
      .join(' · ');
  final fare = day['optimalFareYen'], regular = day['regularFareYen'];
  return '${day['day']}일차 - ${fare is num ? '${fare.toInt()}엔' : '요금 미확인'} (일반 승차권 ${regular is num ? '${regular.toInt()}엔' : '요금 미확인'})\n${names.isEmpty ? '일반 승차권' : names}';
}

String itineraryOverviewDescription(String summary) =>
    summary.split(RegExp(r'주요 방문지(?:는|:)|식사는|방문\s*\d+곳|이동\s*약')).first.trim();
