import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// 편집 중 입력과 생성 완료 결과를 분리합니다. 단계 이동에서는 유지하고 생성 화면을 완전히 나가면 입력을 초기화합니다.
class TripDraft {
  static final instance = TripDraft();
  void handleRouteChange(String? previous, String next) {
    bool inFlow(String? path) =>
        path != null && (path.startsWith('/trip/') || path == '/loading');
    if (inFlow(previous) && !inFlow(next)) resetInputs();
  }

  Map<String, dynamic>? lastGenerated;
  String title = '';
  String get resolvedTitle => title.trim().isNotEmpty
      ? title.trim()
      : cities.isEmpty
      ? '여행'
      : cities.length == 1
      ? '${cities.first} 여행'
      : '${cities.first} ~ ${cities.last} 여행';
  DateTime? start;
  DateTime? end;
  String periodMode = 'dateRange';
  int nights = 0;
  String? entryAirport;
  String? exitAirport;
  TimeOfDay? entryTime;
  TimeOfDay? exitTime;
  List<String> cities = [];
  List<String> customCities = [];
  String pendingCity = '';
  String? confirmedCitySelection;
  bool excludeSuburbs = false;
  bool? restDaysEnabled;
  bool suggestHotel = true;
  int? hotelBudgetYen;
  int? hotelBudgetInput;
  bool hotelBudgetConversionPending = false;
  String defaultHotelBudgetCurrency = 'KRW';
  bool hotelBudgetCurrencyChosen = false;
  String hotelBudgetCurrency = 'KRW';
  String hotelBudgetMode = 'perNight';
  bool get isUndated => periodMode == 'nightsOnly';
  DateTime get inputBase => isUndated ? DateTime(1970, 1, 1) : start!;
  int get tripDays =>
      isUndated ? nights + 1 : end!.difference(start!).inDays + 1;
  String pace = '평범한';
  int mealsPerDay = 2;
  int get maxMealsPerDay =>
      themes.any((theme) => theme == '맛집' || theme == '미식여행') ? 5 : 3;
  bool includeSnacks = false;
  TimeOfDay dailyStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay dailyEnd = const TimeOfDay(hour: 22, minute: 0);
  List<String> companions = [];
  List<String> ageGroups = [];
  List<String> themes = [];
  List<String> excludedThemes = [];
  String? transport;
  String interIslandTransport = '비행기';
  List<Map<String, dynamic>> accommodations = [];
  List<Map<String, dynamic>> fixedSchedules = [];
  Map<String, dynamic> fixedScheduleInput = {};

  static String date(DateTime v) =>
      '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  static String time(TimeOfDay v) =>
      '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  DateTimeRange? get period => isUndated
      ? DateTimeRange(
          start: inputBase,
          end: inputBase.add(Duration(days: nights)),
        )
      : start == null || end == null || end!.isBefore(start!)
      ? null
      : DateTimeRange(start: start!, end: end!);

  bool containsDate(DateTime value) =>
      period != null &&
      !DateUtils.dateOnly(value).isBefore(DateUtils.dateOnly(period!.start)) &&
      !DateUtils.dateOnly(value).isAfter(DateUtils.dateOnly(period!.end));

  // 여행 기간이 바뀌면 범위 밖의 날짜를 비우고 이름과 시간은 유지합니다.
  void constrainDependentDates() {
    for (final a in accommodations) {
      for (final key in ['checkIn', 'checkOut']) {
        final parsed = DateTime.tryParse(a[key]?.toString() ?? '');
        if (parsed != null && !containsDate(parsed)) a[key] = null;
      }
    }
    for (final f in fixedSchedules) {
      final parsed = DateTime.tryParse(f['date']?.toString() ?? '');
      if (parsed != null && !containsDate(parsed)) f['date'] = null;
    }
    final pending = DateTime.tryParse(
      fixedScheduleInput['date']?.toString() ?? '',
    );
    if (pending != null && !containsDate(pending))
      fixedScheduleInput['date'] = null;
  }

  int inputRevision = 0;

  void resetInputs() {
    inputRevision++;
    title = '';
    start = null;
    end = null;
    periodMode = 'dateRange';
    nights = 0;
    entryAirport = null;
    exitAirport = null;
    entryTime = null;
    exitTime = null;
    customCities = [];
    pendingCity = '';
    confirmedCitySelection = null;
    excludeSuburbs = false;
    restDaysEnabled = null;
    pace = '평범한';
    dailyStart = const TimeOfDay(hour: 9, minute: 0);
    dailyEnd = const TimeOfDay(hour: 22, minute: 0);
    mealsPerDay = 2;
    includeSnacks = false;
    cities = [];
    companions = [];
    ageGroups = [];
    themes = [];
    excludedThemes = [];
    transport = null;
    interIslandTransport = '비행기';
    accommodations = [];
    fixedSchedules = [];
    fixedScheduleInput = {};
    suggestHotel = true;
    hotelBudgetYen = null;
    hotelBudgetInput = null;
    hotelBudgetConversionPending = false;
    hotelBudgetCurrency = defaultHotelBudgetCurrency;
    hotelBudgetCurrencyChosen = false;
    hotelBudgetMode = 'perNight';
    _applyDefaults();
  }

  void completeGeneration(Map<String, dynamic> result) {
    lastGenerated = result;
    resetInputs();
  }

  Map<String, dynamic> toRequest() {
    if (period == null ||
        cities.isEmpty ||
        themes.isEmpty ||
        transport == null) {
      throw const FormatException('여행 기간·지역·테마·이동수단을 모두 선택하세요.');
    }
    if (themes.any(excludedThemes.contains)) {
      throw const FormatException('선호 테마와 금지 테마는 중복할 수 없습니다.');
    }
    for (final a in accommodations) {
      final checkIn = DateTime.tryParse(a['checkIn']?.toString() ?? '');
      final checkOut = DateTime.tryParse(a['checkOut']?.toString() ?? '');
      if ('${a['name'] ?? ''}'.trim().isEmpty ||
          checkIn == null ||
          checkOut == null ||
          !containsDate(checkIn) ||
          !containsDate(checkOut) ||
          checkOut.isBefore(checkIn)) {
        throw const FormatException('숙소 이름과 여행 기간 안의 체크인·체크아웃 날짜를 확인하세요.');
      }
    }
    for (final f in fixedSchedules) {
      final selected = DateTime.tryParse(f['date']?.toString() ?? '');
      if (selected == null ||
          !containsDate(selected) ||
          f['startTime'] == null ||
          f['endTime'] == null ||
          f['endTime'].toString().compareTo(f['startTime'].toString()) <= 0) {
        throw const FormatException('고정 일정 날짜와 시작·종료 시간을 확인하세요.');
      }
    }
    if (hotelBudgetConversionPending)
      throw const FormatException('숙소 예산을 환산할 환율을 먼저 불러와 주세요.');
    if (hotelBudgetYen != null &&
        (hotelBudgetYen! <= 0 || hotelBudgetYen! > 1000000000))
      throw const FormatException('숙소 요금 상한은 0보다 큰 엔화 금액으로 입력하세요.');
    // 전송 중인 요청이 편집 초기화/후속 입력으로 변경되지 않게 깊은 복사합니다.
    return Map<String, dynamic>.from(
      jsonDecode(
            jsonEncode({
              'title': resolvedTitle,
              if (!isUndated) 'startDate': date(start!),
              if (!isUndated) 'endDate': date(end!),
              if (isUndated) 'tripDays': tripDays,
              'hotelBudgetYen': hotelBudgetYen,

              'hotelBudgetMode': hotelBudgetMode,
              'cities': cities,
              'inCity': entryAirport,
              'outCity': exitAirport,
              'inTime': entryAirport == null
                  ? null
                  : entryTime != null
                  ? time(entryTime!)
                  : entryAirport != null
                  ? time(dailyStart)
                  : '미정',
              'outTime': exitAirport == null
                  ? null
                  : exitTime != null
                  ? time(exitTime!)
                  : exitAirport != null
                  ? time(dailyEnd)
                  : '미정',
              'companion': companions.join(', '),
              'themes': themes,
              'transportation': transport,
              'interIslandTransportation': interIslandTransport,
              'language': 'ko',
              'accommodations': [
                for (final a in accommodations)
                  if (!isUndated)
                    a
                  else
                    {
                      'name': a['name'],
                      'address': a['address'],
                      'checkInDay':
                          DateTime.parse(
                            a['checkIn'],
                          ).difference(inputBase).inDays +
                          1,
                      'checkOutDay':
                          DateTime.parse(
                            a['checkOut'],
                          ).difference(inputBase).inDays +
                          1,
                    },
              ],
              'fixedSchedules': [
                for (final f in fixedSchedules)
                  if (!isUndated)
                    f
                  else
                    {
                      ...f,
                      'date': null,
                      'dayNumber':
                          DateTime.parse(
                            f['date'],
                          ).difference(inputBase).inDays +
                          1,
                    },
              ],
              'preferredStartTime': '${time(dailyStart)}:00',
              'preferredEndTime': '${time(dailyEnd)}:00',
              'mealsPerDay': mealsPerDay.clamp(1, maxMealsPerDay).toInt(),
              'includeSnacks': includeSnacks,
              'excludeCafe': !includeSnacks,
              'schedulePace': pace,
              'excludedThemes': excludedThemes,
              'suggestHotel': true,
              'restDaysEnabled': restDaysEnabled,
              'excludeSuburbs': excludeSuburbs,
            }),
          )
          as Map,
    );
  }

  final Map<String, dynamic> _defaults = {};
  bool hasDefaults(int step) => _defaults.containsKey('$step');
  Future<void> loadDefaults() async {
    _defaults.clear();
    final prefs = await SharedPreferences.getInstance();
    try {
      _defaults.addAll(
        jsonDecode(prefs.getString('trip.parameter.defaults.v1') ?? '{}')
            as Map<String, dynamic>,
      );
    } on FormatException {
      _defaults.clear();
    }
    _applyDefaults();
  }

  Map<String, dynamic> _snapshot() => {
    'periodMode': periodMode,
    'nights': nights,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'cities': cities,
    'customCities': customCities,
    'excludeSuburbs': excludeSuburbs,
    'entryAirport': entryAirport,
    'exitAirport': exitAirport,
    'entryTime': entryTime == null ? null : time(entryTime!),
    'exitTime': exitTime == null ? null : time(exitTime!),
    'hotelBudgetYen': hotelBudgetYen,
    'hotelBudgetInput': hotelBudgetInput,
    'hotelBudgetCurrency': hotelBudgetCurrency,
    'hotelBudgetMode': hotelBudgetMode,
    'accommodations': accommodations,
    'fixedSchedules': fixedSchedules,
    'restDaysEnabled': restDaysEnabled,
    'interIslandTransport': interIslandTransport,
    'companions': companions,
    'ageGroups': ageGroups,
    'themes': themes,
    'excludedThemes': excludedThemes,
    'transport': transport,
    'pace': pace,
    'dailyStart': time(dailyStart),
    'dailyEnd': time(dailyEnd),
    'mealsPerDay': mealsPerDay,
    'includeSnacks': includeSnacks,
  };
  static const _stepKeys = {
    1: ['periodMode', 'nights', 'start', 'end'],
    2: ['cities', 'customCities', 'excludeSuburbs'],
    3: ['entryAirport', 'exitAirport', 'entryTime', 'exitTime'],
    4: ['hotelBudgetYen', 'hotelBudgetMode', 'accommodations'],
    5: ['fixedSchedules'],
    6: [
      'companions',
      'ageGroups',
      'themes',
      'excludedThemes',
      'transport',
      'pace',
      'dailyStart',
      'dailyEnd',
      'mealsPerDay',
      'includeSnacks',
      'restDaysEnabled',
      'interIslandTransport',
    ],
    7: ['themes', 'excludedThemes'],
    8: ['transport', 'interIslandTransport'],
    9: ['pace', 'dailyStart', 'dailyEnd', 'mealsPerDay', 'includeSnacks'],
  };
  Future<void> saveDefaults(int step) async {
    final snapshot = _snapshot();
    final saved = Map<String, dynamic>.from(_defaults);
    saved['$step'] = jsonDecode(
      jsonEncode({
        for (final k in _stepKeys[step] ?? <String>[]) k: snapshot[k],
      }),
    );
    await (await SharedPreferences.getInstance()).setString(
      'trip.parameter.defaults.v1',
      jsonEncode(saved),
    );
    _defaults
      ..clear()
      ..addAll(saved);
  }

  /// Refresh pinned sections before submission, including requests that later fail.
  Future<void> persistPinnedInputs() async {
    if (_defaults.isEmpty) return;
    final snapshot = _snapshot();
    final saved = Map<String, dynamic>.from(_defaults);
    for (final step in _stepKeys.keys) {
      if (!hasDefaults(step)) continue;
      saved['$step'] = jsonDecode(
        jsonEncode({for (final key in _stepKeys[step]!) key: snapshot[key]}),
      );
    }
    await (await SharedPreferences.getInstance()).setString(
      'trip.parameter.defaults.v1',
      jsonEncode(saved),
    );
    _defaults
      ..clear()
      ..addAll(saved);
  }

  Future<void> clearDefaults(int step) async {
    _defaults.remove('$step');
    await (await SharedPreferences.getInstance()).setString(
      'trip.parameter.defaults.v1',
      jsonEncode(_defaults),
    );
  }

  void _applyDefaults() {
    final m = <String, dynamic>{};
    for (final section in _defaults.values.whereType<Map>())
      m.addAll(Map<String, dynamic>.from(section));
    List<String> list(String k, List<String> fallback) =>
        m[k] is List ? List<String>.from(m[k]) : fallback;
    TimeOfDay? clock(Object? value) {
      final p = value?.toString().split(':');
      return p?.length == 2
          ? TimeOfDay(hour: int.parse(p![0]), minute: int.parse(p[1]))
          : null;
    }

    periodMode = m['periodMode'] ?? periodMode;
    nights = m['nights'] ?? nights;
    start = DateTime.tryParse(m['start']?.toString() ?? '') ?? start;
    end = DateTime.tryParse(m['end']?.toString() ?? '') ?? end;
    cities = list('cities', cities);
    customCities = list('customCities', customCities);
    excludeSuburbs = m['excludeSuburbs'] ?? excludeSuburbs;
    if (m.containsKey('entryAirport')) entryAirport = m['entryAirport'];
    if (m.containsKey('exitAirport')) exitAirport = m['exitAirport'];
    entryTime = clock(m['entryTime']) ?? entryTime;
    exitTime = clock(m['exitTime']) ?? exitTime;
    hotelBudgetYen = m['hotelBudgetYen'] ?? hotelBudgetYen;
    // A pinned budget stores canonical yen; its input currency comes from My Page.
    if (m.containsKey('hotelBudgetYen')) hotelBudgetInput = null;
    hotelBudgetMode = m['hotelBudgetMode'] ?? hotelBudgetMode;
    if (m['accommodations'] is List)
      accommodations = [
        for (final a in m['accommodations']) Map<String, dynamic>.from(a),
      ];
    if (m['fixedSchedules'] is List)
      fixedSchedules = [
        for (final f in m['fixedSchedules']) Map<String, dynamic>.from(f),
      ];
    companions = list('companions', companions);
    ageGroups = list('ageGroups', ageGroups);
    themes = list('themes', themes);
    excludedThemes = list('excludedThemes', excludedThemes);
    transport = m['transport'] ?? transport;
    pace = m['pace'] ?? pace;
    dailyStart = clock(m['dailyStart']) ?? dailyStart;
    dailyEnd = clock(m['dailyEnd']) ?? dailyEnd;
    mealsPerDay = (m['mealsPerDay'] ?? mealsPerDay).clamp(1, maxMealsPerDay);
    includeSnacks = m['includeSnacks'] ?? includeSnacks;
    restDaysEnabled = m['restDaysEnabled'] ?? restDaysEnabled;
    interIslandTransport = m['interIslandTransport'] ?? interIslandTransport;
  }
}
