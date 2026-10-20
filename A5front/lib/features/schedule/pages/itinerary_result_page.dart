import '../widgets/replacement_preferences_dialog.dart';
import '../widgets/city_route_overview.dart';
import '../widgets/itinerary_pdf_card.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/itinerary_place_content.dart';
import '../widgets/pass_day_comparison.dart';
import 'package:public_file_saver/public_file_saver.dart';

import '../widgets/itinerary_route_map.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/state/itinerary_presentation.dart';
import '../../../core/state/money_display.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';

class ItineraryResultPage extends StatefulWidget {
  final PlannerApi? api;
  final bool loadMapTiles;
  final bool showInitialCityRoute;
  final ItinerarySummary? summary;
  final Map<String, dynamic>? response;
  final Map<String, dynamic>? request;

  const ItineraryResultPage({
    super.key,
    this.api,
    this.loadMapTiles = true,
    this.showInitialCityRoute = true,
    this.summary,
    this.response,
    this.request,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  late bool isSaved;
  Map<String, dynamic>? _response;
  Map<String, dynamic>? _request;
  bool _isSaving = false;
  int? get _planId => (_response?['planId'] as num?)?.toInt();
  PlannerApi get _api => widget.api ?? PlannerApi.instance;
  bool _isProcessingPdf = false;
  bool _moneyLoading = true;
  bool get _moneyReady =>
      _api.money.currency == 'JPY' || _api.money.krwPerJpy != null;

  final PublicFileSaver _fileSaver = PublicFileSaver();

  final ScrollController _contentController = ScrollController();

  GoogleMapController? _mapController;

  int selectedDayIndex = 0;
  int? _selectedItemIndex;
  int _selectionRevision = 0;
  bool _showActions = true;
  bool _showPinNavigation = false;
  bool _isMapPinned = true;
  final Map<int, GlobalKey> _dayMapKeys = {};
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _scrollViewportKey = GlobalKey();
  GlobalKey _itemKey(int index) =>
      _itemKeys.putIfAbsent('$selectedDayIndex-$index', () => GlobalKey());
  void _selectItem(int index, {bool scroll = false}) {
    if (index < 0 || index >= currentDay.items.length) return;
    setState(() {
      _selectedItemIndex = index;
      _selectionRevision++;
    });
    if (scroll)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _itemKey(index).currentContext;
        final box = target?.findRenderObject();
        final viewport = _scrollViewportKey.currentContext?.findRenderObject();
        if (box is RenderBox &&
            viewport is RenderBox &&
            _contentController.hasClients) {
          final delta =
              box.localToGlobal(Offset.zero).dy -
              viewport.localToGlobal(Offset.zero).dy;
          final offset =
              (_contentController.offset +
                      delta -
                      (_isMapPinned ? _mapSectionHeight : 0) -
                      12)
                  .clamp(0.0, _contentController.position.maxScrollExtent);
          _contentController.animateTo(
            offset,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      });
  }

  bool _handleUserScroll(UserScrollNotification notice) {
    if (notice.depth != 0 ||
        notice.metrics.axis != Axis.vertical ||
        notice.direction == ScrollDirection.idle)
      return false;
    final show = notice.direction == ScrollDirection.forward;
    if (_showActions != show) setState(() => _showActions = show);
    return false;
  }

  // 서버의 확인된 구간 요금과 패스 비교 결과를 표시합니다.
  Map<String, dynamic>? get _costs => _response?['transportCosts'] is Map
      ? Map<String, dynamic>.from(_response!['transportCosts'] as Map)
      : null;
  String _passPeriod(Map row) => itineraryPassPeriod(
    row,
    DateTime.tryParse(_request?['startDate']?.toString() ?? ''),
  );

  String shown(String text) => itineraryVisibleText(
    _api.money.text(text),
    admin: _api.showAdminInformation,
  );
  Map<String, List<String>> get _guidance => itineraryGuidance(
    (_response?['warnings'] as List? ?? [])
        .map((w) => shown('$w'))
        .where((w) => w.isNotEmpty)
        .toList(),
  );
  String get recommendedPass {
    final text = shown(itineraryPassSummary(_costs));
    return text.isEmpty ? '일반 승차권을 이용할 수 있습니다.' : text;
  }

  Map<String, String> dayGuidance(_ItineraryDay day) {
    final visits = day.items
        .where((i) => !RegExp(r'숙소|숙박|교통|공항|자유|식사|식음|간식').hasMatch(i.category))
        .toList();
    final meals = day.items
        .where((i) => RegExp(r'식사|식음|간식').hasMatch(i.category))
        .toList();
    final daily = (_costs?['dailyCosts'] as List? ?? [])
        .whereType<Map>()
        .where((d) => d['day'] == day.dayNumber)
        .firstOrNull;
    final fare = daily?['optimalFareYen'] ?? daily?['regularFareYen'];
    final durations = visits
        .map(
          (i) => RegExp(r'체류시간: (\d+)분').firstMatch(i.displayDescription ?? ''),
        )
        .whereType<RegExpMatch>()
        .map((m) => int.parse(m[1]!))
        .fold<int>(0, (a, b) => a + b);
    final values = <String, String>{
      '설명': shown(
        day.overview.isEmpty
            ? '${widget.summary?.region ?? (_request?['cities'] as List? ?? []).join(' · ')} 방문 일정'
            : itineraryOverviewDescription(day.overview),
      ),
      '관광지': visits.map((i) => i.title).join(' · '),
      '식사 장소': meals.map((i) => i.title).join(' · '),
      '관광 시간': durations > 0 ? '총 $durations분' : '',
      '교통비': fare is num ? shown('성인 1인 · 약 ¥${fare.toInt()}') : '',
      '패스 비교': daily == null ? '' : shown(itineraryCompactPassDay(daily)),
    };
    values.removeWhere((key, value) => value.isEmpty);
    return values;
  }

  Widget buildDayGuidance(_ItineraryDay day) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '일정 안내',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        for (final field in dayGuidance(day).entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    field.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(field.value, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  String get _airfareText {
    final cost = _costs;
    final flights = (cost?['flightLegCount'] as num?)?.toInt() ?? 0;
    final unknown = (cost?['unknownFlightLegCount'] as num?)?.toInt() ?? 0;
    if (flights == 0) return '';
    final domestic = flights == 0
        ? ''
        : unknown > 0
        ? '국내선 항공료: 확인된 소계 ¥${cost?['knownFlightFareYen'] ?? 0} · 미확인 $unknown구간'
        : '일정 내 예상 국내선 항공료 ¥${cost?['flightFareYen'] ?? 0}';
    return '$domestic\n공항까지의 철도·버스 요금은 대중교통비에 포함';
  }

  String get _costText => shown(_rawCostText);
  String get _rawCostText {
    final cost = _costs;
    if (cost == null) return '교통비 정보가 없습니다. 다시 생성하면 수집 자료를 반영합니다.';
    final unknown = (cost['unknownLegCount'] as num?)?.toInt() ?? 0;
    const routingNotice = '';
    if (unknown > 0) {
      return '${routingNotice}대중교통비 계산 미완료\n성인 1인 · 확인된 대중교통 소계 ¥${cost['knownFareYen'] ?? 0}\n요금 미확인 이동 $unknown개 · 이 금액은 전체 여행 교통비가 아닙니다.\n$_airfareText';
    }
    final estimated = (cost['estimatedLegCount'] as num? ?? 0).toInt();
    final estimateNotice = estimated > 0 ? '예상 요금 포함: $estimated개 구간\n' : '';
    return '$routingNotice${estimateNotice}성인 1인 · ${estimated > 0 ? '예상 ' : ''}대중교통비 ¥${cost['totalFareYen'] ?? cost['knownFareYen']}\n패스 적용 대중교통비 ¥${cost['knownOptimalFareYen']}\n$_airfareText';
  }

  // =========================================================
  // 날짜별 여행 일정
  //
  // 저장된 서버 응답만 표시합니다.
  // =========================================================

  late List<_ItineraryDay> days;

  _ItineraryDay get currentDay => days[selectedDayIndex];

  Set<Marker> get _currentMarkers {
    final day = currentDay;

    return {
      for (int index = 0; index < day.items.length; index++)
        if (day.items[index].hasLocation)
          Marker(
            markerId: MarkerId('day_${day.dayNumber}_$index'),
            position: day.items[index].position!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: day.items[index].title,
              snippet: [
                day.items[index].time,
                day.items[index].category,
                day.items[index].transportDescription,
                day.items[index].displayDescription ?? '',
                day.items[index].explanation ?? day.items[index].description,
              ].where((v) => v.isNotEmpty).join('\n'),
            ),
          ),
    };
  }

  LatLng get _initialMapTarget {
    for (final item in currentDay.items) {
      if (item.hasLocation) {
        return item.position!;
      }
    }

    return const LatLng(35.681236, 139.767125);
  }

  String _placeDescription(Map<String, dynamic> place) =>
      shown(itineraryDescription(place));

  @override
  void initState() {
    super.initState();

    _response = widget.response;
    _request = widget.request;
    isSaved = _response != null;
    _readDays();
    _api.money.addListener(_moneyChanged);
    _api.addListener(_moneyChanged);
    _loadMoney();
    if (widget.showInitialCityRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCityRoute();
      });
    }
  }

  Future<void> _showCityRoute() async {
    final stops = itineraryCityStops(_request ?? {}, _response ?? {});
    if (stops.isEmpty) return;
    final day = await showDialog<int>(
      context: context,
      builder: (_) =>
          CityRouteOverview(stops: stops, loadTiles: widget.loadMapTiles),
    );
    if (mounted && day != null) {
      final index = days.indexWhere((d) => d.dayNumber == day);
      if (index >= 0) _handleDayChanged(index);
    }
  }

  double get _mapSectionHeight =>
      (MediaQuery.sizeOf(context).height * .42).clamp(225.0, 375.0) +
      44 +
      (_showPinNavigation &&
              currentDay.items.any((item) => item.mapNumber != null)
          ? 54
          : 0);

  Widget _pinNavigation() {
    final located = currentDay.items.indexed
        .where((e) => e.$2.mapNumber != null)
        .toList();
    if (located.isEmpty) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: SizedBox(
          height: 54,
          child: ListView.separated(
            key: const ValueKey('map-pin-navigation'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            scrollDirection: Axis.horizontal,
            itemCount: located.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (index, item) = located[i];
              return Tooltip(
                message: item.title,
                child: ChoiceChip(
                  key: ValueKey('map-pin-button-${item.mapNumber}'),
                  label: Text(
                    '${item.mapNumber}. ${item.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  showCheckmark: false,
                  selected: _selectedItemIndex == index,
                  onSelected: (_) => _selectItem(index, scroll: true),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _moneyChanged() {
    if (mounted) setState(_readDays);
  }

  Future<void> _loadMoney() async {
    if (mounted) setState(() => _moneyLoading = true);
    try {
      final currency = await _api.getHotelCurrencyPreference();
      if (!mounted) return;
      _api.money.configure(currency: currency);
    } catch (_) {}
    try {
      final rate = await _api.getExchangeRate();
      if (!mounted) return;
      _api.money.configure(rate: rate['krwPerJpy'] as num?);
    } catch (_) {}
    if (mounted) setState(() => _moneyLoading = false);
  }

  void _readDays() {
    if (_response == null) {
      days = [_ItineraryDay(dayNumber: 1, dateLabel: '', items: [])];
    } else {
      final timeline =
          (_response!['timeline'] as List? ?? [])
              .whereType<Map>()
              .map(itineraryNormalizePlace)
              .toList()
            ..sort((a, b) {
              final day = ((a['day'] as num?)?.toInt() ?? 0).compareTo(
                (b['day'] as num?)?.toInt() ?? 0,
              );
              if (day != 0) return day;
              return itineraryOrder(a).compareTo(itineraryOrder(b));
            });
      itineraryMarkLodgingDepartures(timeline);
      itineraryAttachAirportAccess(timeline);
      itineraryAttachLodgingPrices(
        timeline,
        (_response!['lodgings'] as List? ?? []).whereType<Map>().toList(),
      );
      itineraryIncludeStayBuffer(timeline);
      if (timeline.isNotEmpty &&
          (_request!['inCity']?.toString().trim().isEmpty ?? true)) {
        final first = timeline.first;
        first['_hideEmptyStartFields'] = true;
        final leg = first['transportFromPrevious'];
        if (leg is Map &&
            (leg['durationMinutes'] as num? ?? 0) <= 0 &&
            (leg['steps'] as List? ?? []).isEmpty) {
          first.remove('transportFromPrevious');
          first.remove('transit');
        }
      }
      final actualStart = DateTime.tryParse(
        _request!['startDate']?.toString() ?? '',
      );
      if (actualStart != null) {
        for (final place in timeline) {
          place['_visitWeekday'] =
              actualStart
                  .add(Duration(days: (place['day'] as num).toInt() - 1))
                  .weekday -
              1;
        }
      }
      final start = actualStart ?? DateTime(1970);
      final end =
          DateTime.tryParse(_request!['endDate']?.toString() ?? '') ??
          start.add(Duration(days: (_request!['tripDays'] as num).toInt() - 1));
      days = List.generate(
        end.difference(start).inDays + 1,
        (i) => _ItineraryDay(
          dayNumber: i + 1,
          overview:
              ((_response!['days'] as List? ?? [])
                          .whereType<Map>()
                          .where((d) => (d['day'] as num?)?.toInt() == i + 1)
                          .map((d) => d['summary']?.toString() ?? '')
                          .firstOrNull ??
                      '')
                  .trim(),
          dateLabel: actualStart == null
              ? (i == 0 ? '날짜 미지정' : '')
              : '${start.add(Duration(days: i)).year}.${start.add(Duration(days: i)).month}.${start.add(Duration(days: i)).day}',
          items: timeline
              .where((e) => (e['day'] as num?)?.toInt() == i + 1)
              .map(
                (e) => _ItineraryItem(
                  geometry:
                      (((e['transportFromPrevious'] as Map?)?['geometry']
                                  as List?) ??
                              [])
                          .whereType<Map>()
                          .where(
                            (p) =>
                                p['latitude'] is num && p['longitude'] is num,
                          )
                          .map(
                            (p) => [
                              (p['latitude'] as num).toDouble(),
                              (p['longitude'] as num).toDouble(),
                            ],
                          )
                          .toList(),
                  geometrySource:
                      (e['transportFromPrevious'] as Map?)?['geometrySource']
                          ?.toString() ??
                      '',
                  hasTransport: e['transportFromPrevious'] is Map,
                  driving: itineraryDriving(
                    (e['transportFromPrevious'] as Map?)?['mode'],
                  ),
                  airborne:
                      (e['transportFromPrevious'] as Map?)?['source'] ==
                      'domestic-flight-fare',
                  walking:
                      (e['transportFromPrevious'] as Map?)?['mode'] == '도보',
                  airportAccessUrl: e['_airportAccessUrl'] as Uri?,
                  itineraryId: ((e['itineraryId'] ?? e['id']) as num?)?.toInt(),
                  time: e['time']?.toString() ?? '',
                  title: e['placeName']?.toString() ?? '',
                  description: _placeDescription(Map<String, dynamic>.from(e)),
                  displayDescription: shown(
                    itineraryPlaceInformation(
                      e,
                      admin: _api.showAdminInformation,
                    ),
                  ),
                  explanation: shown(itineraryPlaceExplanation(e)),
                  transportDescription: e['transportFromPrevious'] is Map
                      ? shown(
                          itineraryDescription({
                            'transportFromPrevious': e['transportFromPrevious'],
                          }),
                        )
                      : '',
                  category: itineraryCategory(e),
                  latitude: (e['latitude'] as num?)?.toDouble(),
                  longitude: (e['longitude'] as num?)?.toDouble(),
                ),
              )
              .toList(),
        ),
      );
    }

    for (final day in days) {
      int number = 0;
      _ItineraryItem? previous;
      for (final item in day.items) {
        item.directionsUrl = null;
        if (item.hasLocation && previous != null && !item.airborne) {
          item.directionsUrl = itineraryDirectionsUrl(
            {'latitude': previous.latitude, 'longitude': previous.longitude},
            {'latitude': item.latitude, 'longitude': item.longitude},
            walking: item.walking,
            driving: item.driving,
          );
        }
        if (item.hasLocation) previous = item;
        item.mapNumber = item.hasLocation ? ++number : null;
      }
    }
  }

  @override
  void dispose() {
    _api.money.removeListener(_moneyChanged);
    _api.removeListener(_moneyChanged);
    _contentController.dispose();
    super.dispose();
  }

  // =========================================================
  // 지도 카메라
  // =========================================================

  Future<void> _updateMapCamera() async {
    final controller = _mapController;

    if (controller == null) return;

    final positions = currentDay.items
        .where((item) => item.hasLocation)
        .map((item) => item.position!)
        .toList();

    if (positions.isEmpty) return;

    // PageView 변경 직후 Google Map 레이아웃이 갱신될 시간을 확보
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted || _mapController != controller) {
      return;
    }

    try {
      if (positions.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(positions.first, 14.5),
        );

        return;
      }

      double minLatitude = positions.first.latitude;
      double maxLatitude = positions.first.latitude;
      double minLongitude = positions.first.longitude;
      double maxLongitude = positions.first.longitude;

      for (final position in positions.skip(1)) {
        minLatitude = math.min(minLatitude, position.latitude);
        maxLatitude = math.max(maxLatitude, position.latitude);
        minLongitude = math.min(minLongitude, position.longitude);
        maxLongitude = math.max(maxLongitude, position.longitude);
      }

      // 모든 좌표가 사실상 같은 위치인 경우
      if (minLatitude == maxLatitude && minLongitude == maxLongitude) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(positions.first, 14.5),
        );

        return;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLatitude, minLongitude),
        northeast: LatLng(maxLatitude, maxLongitude),
      );

      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 54));
    } catch (_) {
      // 지도 생성 직후 카메라 이동 실패 시 화면 동작에는 영향 없음
    }
  }

  Widget _dayNavigation(String position) => Row(
    key: ValueKey('day-navigation-$position'),
    children: [
      Expanded(
        child: TextButton(
          key: ValueKey('day-$position-previous'),
          onPressed: selectedDayIndex > 0
              ? () => _handleDayChanged(selectedDayIndex - 1)
              : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 19),
              SizedBox(width: 5),
              Flexible(child: Text('이전 일차', textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${selectedDayIndex + 1}/${days.length}일차',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(
        child: TextButton(
          key: ValueKey('day-$position-next'),
          onPressed: selectedDayIndex < days.length - 1
              ? () => _handleDayChanged(selectedDayIndex + 1)
              : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text('다음 일차', textAlign: TextAlign.center)),
              SizedBox(width: 5),
              Icon(Icons.arrow_forward, size: 19),
            ],
          ),
        ),
      ),
    ],
  );

  void _handleDayChanged(int index) {
    if (selectedDayIndex == index) return;

    setState(() {
      selectedDayIndex = index;
      _selectedItemIndex = null;
      _showActions = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _contentController.hasClients)
        _contentController.jumpTo(0);
    });
    _updateMapCamera();
  }

  // =========================================================
  // 뒤로가기 / 저장
  // =========================================================

  Future<bool> _handleBack() async {
    if (_isSaving) {
      _notice('변경 내용을 저장하고 있습니다. 잠시 기다려 주세요.');
      return false;
    }
    context.go(AppRoutes.schedule);
    return false;
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveSchedule() =>
      _notice(isSaved ? '일정과 변경 내용은 자동으로 저장됩니다.' : '일정을 먼저 생성하세요.');

  Future<void> _applyChange(
    Future<Map<String, dynamic>> Function() action, {
    bool regenerated = false,
  }) async {
    if (_isSaving || _planId == null) return;
    setState(() => _isSaving = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _response = regenerated
            ? result
            : Map<String, dynamic>.from(result['response'] as Map);
        if (!regenerated)
          _request = Map<String, dynamic>.from(result['request'] as Map);
        isSaved = true;
        _readDays();
        if (selectedDayIndex >= days.length) selectedDayIndex = 0;
      });
      _updateMapCamera();
      _notice('변경된 일정이 자동 저장되었습니다.');
    } catch (e) {
      _notice('변경을 저장하지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // =========================================================
  // 일정 삭제
  //
  // 삭제된 시간대는 그대로 유지하며 지도 마커에서는 제외합니다.
  // =========================================================

  Future<int?> _resolveItemId(_ItineraryDay day, _ItineraryItem item) async {
    if (item.itineraryId != null) return item.itineraryId;
    try {
      final saved = await _api.getPlan(_planId!);
      final response = saved['response'] as Map;
      final rows = (response['timeline'] as List)
          .whereType<Map>()
          .where((row) => row['day'] == day.dayNumber)
          .toList();
      final index = day.items.indexOf(item);
      if (index >= 0 && index < rows.length)
        item.itineraryId =
            ((rows[index]['itineraryId'] ?? rows[index]['id']) as num?)
                ?.toInt();
      if (item.itineraryId == null)
        _notice('일정 항목을 확인하지 못했습니다. 일정을 다시 열어 주세요.');
    } catch (error) {
      _notice('저장된 일정 정보를 확인하지 못했습니다: $error');
    }
    return item.itineraryId;
  }

  Future<void> _deleteItem(_ItineraryDay day, _ItineraryItem item) async {
    if (_isSaving || _planId == null) return;
    if (await _resolveItemId(day, item) == null || !mounted) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '일정을 삭제하시겠습니까?',
      message: '${item.time} ${item.title} 일정이 삭제되고 자동 저장됩니다.',
      confirmText: '삭제',
      type: AppConfirmDialogType.danger,
    );
    if (!confirmed || !mounted) return;
    await _applyChange(() => _api.deletePlanItem(_planId!, item.itineraryId!));
  }

  // =========================================================
  // AI 대체 장소 추천
  // =========================================================

  Future<void> _showEditRecommendations(
    _ItineraryDay day,
    _ItineraryItem item,
  ) async {
    if (_isSaving || _planId == null) return;
    if (await _resolveItemId(day, item) == null || !mounted) return;
    final preferences = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => ReplacementPreferencesDialog(
        companion: _request?['companion']?.toString() ?? '혼자',
      ),
    );
    if (preferences == null || !mounted) return;
    setState(() => _isSaving = true);
    List<Map<String, dynamic>> choices;
    try {
      choices = await _api.planItemAlternatives(
        _planId!,
        item.itineraryId!,
        preferences: preferences,
      );
    } catch (e) {
      _notice('대체 장소를 조회하지 못했습니다: $e');
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;
    if (choices.isEmpty) {
      _notice('체류시간을 줄여도 선택한 조건과 남은 일정에 맞는 다른 장소를 찾지 못했습니다. 다른 테마를 선택해 주세요.');
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${item.time} 대체 장소',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...choices.map(
              (choice) => ListTile(
                title: Text(choice['placeName']?.toString() ?? ''),
                subtitle: Text(
                  [
                    choice['address']?.toString() ?? '',
                    if (choice['stayMinutes'] is num)
                      '예상 체류시간: ${choice['stayMinutes']}분',
                  ].where((s) => s.isNotEmpty).join('\n'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, choice),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '선택한 장소로 재설정할까요?',
      message:
          '해당 일차를 변경하면 체류시간과 남은 일정의 시간이 조정될 수 있습니다. 이후 관광지·식사 장소·숙소는 유지됩니다.${RegExp(r"숙소|숙박|호텔|료칸").hasMatch(item.category) ? " 숙소 변경 시 다음 날 출발 숙소와 이동 시간도 다시 계산합니다." : ""}',
      confirmText: '재설정',
    );
    if (!confirmed || !mounted) return;
    await _applyChange(
      () => _api.replacePlanItem(
        _planId!,
        item.itineraryId!,
        selected['placeId'].toString(),
        preferences: preferences,
      ),
    );
  }

  void _showItemMenu(_ItineraryDay day, _ItineraryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BottomSheetAction(
                  icon: Icons.auto_awesome_rounded,
                  label: '대체 장소 추천',
                  onTap: () {
                    Navigator.pop(context);

                    _showEditRecommendations(day, item);
                  },
                ),

                _BottomSheetAction(
                  icon: Icons.delete_rounded,
                  label: '삭제',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);

                    _deleteItem(day, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _regenerateSchedule() async {
    if (_isSaving || _planId == null || _request == null) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '일정을 다시 생성하시겠습니까?',
      message:
          '현재 일정이 새 일정으로 바뀌고 자동 저장됩니다. 이미 받은 PDF 파일은 그대로 유지됩니다.${_api.money.currency == 'KRW' ? '\n\n${MoneyDisplay.roundingNotice}' : ''}',
      confirmText: '재생성',
    );
    if (!confirmed || !mounted) return;
    await _applyChange(
      () => _api.regeneratePlan(_planId!, _request!),
      regenerated: true,
    );
  }

  // =========================================================
  // 추천 교통패스
  // =========================================================

  void _showRecommendedPass() {
    final costs = _costs;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('대중교통 비용·패스 비교'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_costText),
                const SizedBox(height: 16),
                Text(recommendedPass),
                const SizedBox(height: 12),
                PassDayComparison(costs: costs, formatText: shown),
                if (_api.showAdminInformation &&
                    _planId != null &&
                    (_costs?['unknownLegCount'] as num? ?? 0) > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('거리 평균 시간·요금 계산'),
                    onPressed: () {
                      try {
                        _api.startGeneration({
                          ...?_request,
                          'researchPlanId': _planId,
                        });
                        Navigator.pop(dialogContext);
                        _notice('서버에서 교통 정보를 보완합니다. 완료되면 팝업으로 알려드립니다.');
                      } catch (e) {
                        _notice(e.toString());
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PDF
  // =========================================================

  String _buildPdfFileName(String title) {
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    final fileTitle = safeTitle.isEmpty ? 'AI_여행_일정' : safeTitle;

    return '${fileTitle}_일정.pdf';
  }

  List<pw.Widget> _buildPdfItem(
    _ItineraryItem item, {
    String? detailKey,
    bool expanded = false,
  }) => itineraryPdfCard(
    title: item.title,
    time: item.time,
    category: item.category,
    number: item.mapNumber,
    information: item.displayDescription ?? '',
    movement: item.transportDescription,
    explanation: item.explanation ?? '',
    directionsUrl: item.directionsUrl,
    airportAccessUrl: item.airportAccessUrl,
    detailKey: detailKey,
    expanded: expanded,
  );

  Future<Uint8List> _generateSchedulePdf() async {
    final summary = widget.summary ?? ItinerarySummary.defaultGenerated();
    final regular = await PdfGoogleFonts.notoSansKRRegular();
    final bold = await PdfGoogleFonts.notoSansKRBold();
    final japanese = await PdfGoogleFonts.notoSansJPRegular();
    final passes = itineraryPdfPassRecommendations(_costs);
    final costs = <String, String>{};
    final transit =
        _costs?['knownOptimalFareYen'] ??
        _costs?['totalFareYen'] ??
        _response?['transitFareWithPassesYen'] ??
        _response?['transitFareYen'];
    if (transit is num) costs['대중교통비 (1인)'] = _api.money.yen(transit);
    final lodging = _response?['lodgingCostYen'];
    final adultCount = ((_response?['adults'] ?? _request?['adults']) as num?)
        ?.toInt();
    if (lodging is num && adultCount != null && adultCount > 0)
      costs['숙박비 (성인 1인당)'] = _api.money.yen(lodging / adultCount);
    final flight = _costs?['flightFareYen'];
    if ((_costs?['flightLegCount'] as num? ?? 0) > 0 && flight is num)
      costs['일본 국내선 (1인)'] = _api.money.yen(flight);
    final stays = <Map<String, String>>[
      for (final stay
          in (_response?['lodgings'] as List? ?? []).whereType<Map>())
        {
          'name': '${stay['name'] ?? ''}',
          'period':
              '${stay['checkInDay']}일차 ~ ${stay['checkOutDay']}일차 (${stay['nights']}박)',
          'price': stay['lowestNightPerRoomYen'] is num
              ? _api.money.yen(stay['lowestNightPerRoomYen'] as num)
              : '',
        },
    ];
    String airport(String city, String time) {
      final name = _request?[city]?.toString().trim() ?? '';
      return name.isEmpty
          ? ''
          : [
              name,
              _request?[time]?.toString() ?? '',
            ].where((s) => s.isNotEmpty).join(' · ');
    }

    return buildDonghwiSchedulePdf(
      regular: regular,
      bold: bold,
      japanese: japanese,
      title: summary.title,
      period:
          '${summary.duration} · ${DateTime.tryParse(_request?['startDate']?.toString() ?? '') == null ? '날짜 미지정' : summary.period}',
      information: {
        '도시': summary.region,
        '동행': _request?['companion']?.toString() ?? '',
        '테마': summary.theme,
        '이동 수단': _request?['transportation']?.toString() ?? '',
        '입국': airport('inCity', 'inTime'),
        '출국': airport('outCity', 'outTime'),
      },
      costs: costs,
      lodgings: stays,
      passes: [
        for (final pass in passes)
          shown(
            '${_passPeriod(pass)} · ¥${pass['savingYen'] ?? ((pass['regularFareYen'] as num) - (pass['passFareYen'] as num))} 절약',
          ),
        for (final day in itineraryPdfPassDays(_costs))
          shown(itineraryDailyCostText(day)),
      ],
      comment: shown(_response?['reason']?.toString() ?? ''),
      notes: [
        if (_api.money.currency == 'KRW') MoneyDisplay.roundingNotice,
        ..._guidance.values.expand((v) => v),
      ],
      days: [
        for (final day in days)
          ItineraryPdfDay(
            number: day.dayNumber,
            date: day.dateLabel,
            guidance: dayGuidance(day),
            items: [
              for (var i = 0; i < day.items.length; i++)
                ..._buildPdfItem(
                  day.items[i],
                  detailKey: 'day-${day.dayNumber}-stop-$i',
                ),
            ],
            details: [
              for (var i = 0; i < day.items.length; i++)
                ..._buildPdfItem(
                  day.items[i],
                  detailKey: 'day-${day.dayNumber}-stop-$i',
                  expanded: true,
                ),
            ],
          ),
      ],
    );
  }

  void _showPdfActions() {
    if (!isSaved ||
        _isSaving ||
        _isProcessingPdf ||
        !_moneyReady ||
        _moneyLoading) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '일정 PDF',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 6),

                Text(
                  '완성된 일정을 기기에 저장하거나 다른 앱으로 공유할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                _PdfActionTile(
                  icon: Icons.download_rounded,
                  title: '기기에 저장',
                  description: 'PDF 파일을 Download/AI Travel Planner 폴더에 저장합니다.',
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _saveSchedulePdf();
                  },
                ),

                const SizedBox(height: 8),

                _PdfActionTile(
                  icon: Icons.share_rounded,
                  title: '공유',
                  description: '메신저, 메일 등 다른 앱으로 PDF 파일을 공유합니다.',
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _shareSchedulePdf();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSchedulePdf() async {
    if (!isSaved ||
        _isSaving ||
        _isProcessingPdf ||
        !_moneyReady ||
        _moneyLoading) {
      return;
    }

    setState(() {
      _isProcessingPdf = true;
    });

    try {
      final displaySummary =
          widget.summary ?? ItinerarySummary.defaultGenerated();

      final pdfBytes = await _generateSchedulePdf();

      final fileName = _buildPdfFileName(displaySummary.title);

      final result = await _fileSaver.saveBytes(
        bytes: pdfBytes,
        fileName: fileName,
        mimeType: 'application/pdf',
        subDir: 'AI Travel Planner',
      );

      if (!mounted) return;

      if (result != null && result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF가 Download/AI Travel Planner 폴더에 저장되었습니다.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF를 저장하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF를 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPdf = false;
        });
      }
    }
  }

  Future<void> _shareSchedulePdf() async {
    if (!isSaved ||
        _isSaving ||
        _isProcessingPdf ||
        !_moneyReady ||
        _moneyLoading) {
      return;
    }

    setState(() {
      _isProcessingPdf = true;
    });

    try {
      final displaySummary =
          widget.summary ?? ItinerarySummary.defaultGenerated();

      final pdfBytes = await _generateSchedulePdf();

      final fileName = _buildPdfFileName(displaySummary.title);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
        subject: '${displaySummary.title} 여행 일정',
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF를 생성하거나 공유하지 못했습니다. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPdf = false;
        });
      }
    }
  }

  // =========================================================
  // 화면
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final displaySummary =
        widget.summary ??
        (_request != null && _response != null
            ? ItinerarySummary.fromBackend(_request!, _response!)
            : ItinerarySummary.defaultGenerated());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              if (!_moneyReady)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _moneyLoading
                              ? '금액을 원화로 환산하고 있습니다.'
                              : '원화 금액을 불러오지 못했습니다.',
                        ),
                      ),
                      if (!_moneyLoading)
                        TextButton(
                          onPressed: _loadMoney,
                          child: const Text('다시 불러오기'),
                        ),
                    ],
                  ),
                ),
              // =================================================
              // 상단
              //
              // 기존 PDF / 저장 여부 UI 유지
              // =================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _handleBack,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        displaySummary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    Tooltip(
                      message: isSaved ? 'PDF 저장 및 공유' : '일정을 저장하면 사용할 수 있습니다.',
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap:
                              isSaved &&
                                  !_isSaving &&
                                  !_isProcessingPdf &&
                                  _moneyReady &&
                                  !_moneyLoading
                              ? _showPdfActions
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Center(
                              child: _isProcessingPdf
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.download_rounded,
                                      size: 22,
                                      color: isSaved
                                          ? AppColors.primary
                                          : AppColors.textSecondary.withOpacity(
                                              0.35,
                                            ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      key: const ValueKey('show-city-route'),
                      tooltip: '도시 경로 다시보기',
                      onPressed: _showCityRoute,
                      icon: const Icon(
                        Icons.route_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSaved
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.warning.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isSaved ? (_isSaving ? '저장 중…' : '자동 저장됨') : '저장 전',
                        style: TextStyle(
                          color: isSaved
                              ? AppColors.success
                              : const Color(0xFF9A6B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  key: _scrollViewportKey,
                  onNotification: _handleUserScroll,
                  child: CustomScrollView(
                    controller: _contentController,
                    key: const ValueKey('itinerary-day-scroll'),
                    slivers: [
                      SliverPersistentHeader(
                        pinned: _isMapPinned,
                        delegate: _ItineraryMapHeader(
                          extent: _mapSectionHeight,
                          child: ColoredBox(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 840,
                                      ),
                                      child: _ItineraryMapCard(
                                        key: _dayMapKeys.putIfAbsent(
                                          currentDay.dayNumber,
                                          () => GlobalKey(),
                                        ),
                                        loadTiles: widget.loadMapTiles,
                                        pinsVisible: _showPinNavigation,
                                        onTogglePins: () => setState(
                                          () => _showPinNavigation =
                                              !_showPinNavigation,
                                        ),
                                        height:
                                            (MediaQuery.sizeOf(context).height *
                                                    .42)
                                                .clamp(225.0, 375.0),
                                        selectionRevision: _selectionRevision,
                                        selectedItemIndex: _selectedItemIndex,
                                        onItemSelected: (index) =>
                                            _selectItem(index, scroll: true),
                                        airportDirections: {
                                          for (
                                            var i = 0;
                                            i < currentDay.items.length;
                                            i++
                                          )
                                            i: currentDay
                                                .items[i]
                                                .airportAccessUrl,
                                        },
                                        directions: {
                                          for (final item in currentDay.items)
                                            if (item.mapNumber != null)
                                              currentDay.items.indexOf(item):
                                                  item.directionsUrl,
                                        },
                                        paths: currentDay.items
                                            .where(
                                              (i) => i.geometry.length >= 2,
                                            )
                                            .map(
                                              (i) => RouteMapPath(
                                                coordinates: i.geometry,
                                                source: i.geometrySource,
                                              ),
                                            )
                                            .toList(),
                                        initialTarget: _initialMapTarget,
                                        markers: _currentMarkers,
                                        onMapCreated: (controller) {
                                          _mapController = controller;

                                          _updateMapCamera();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 44,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          key: const ValueKey(
                                            'toggle-fixed-map',
                                          ),
                                          onPressed: () => setState(
                                            () => _isMapPinned = !_isMapPinned,
                                          ),
                                          icon: Icon(
                                            _isMapPinned
                                                ? Icons.lock_open_rounded
                                                : Icons.lock_outline_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _isMapPinned ? '지도 고정 해제' : '지도 고정',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_showPinNavigation) _pinNavigation(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 840),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // =================================================
                                  // 기존 파란 여행 정보 박스 대신 지도
                                  // =================================================

                                  const SizedBox(height: 16),

                                  // =================================================
                                  // 현재 날짜 + 추천 패스
                                  // =================================================
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${currentDay.dayNumber}일차 일정',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),

                                            const SizedBox(height: 4),

                                            if (currentDay.dateLabel.isNotEmpty)
                                              Text(
                                                currentDay.dateLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      OutlinedButton.icon(
                                        onPressed: _showRecommendedPass,
                                        icon: const Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          '패스 상세보기',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(
                                            color: AppColors.primary,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      recommendedPass,
                                      style: const TextStyle(height: 1.5),
                                    ),
                                  ),
                                  if (_guidance.isNotEmpty)
                                    ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      expandedCrossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      title: const Text(
                                        '추가 안내',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      children: [
                                        for (final group in _guidance.entries)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F6F9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  group.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                for (final message
                                                    in group.value)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 5,
                                                        ),
                                                    child: Text(
                                                      message,
                                                      style: const TextStyle(
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  buildDayGuidance(currentDay),
                                  const SizedBox(height: 12),

                                  // =================================================
                                  // 날짜 페이지 위치 표시
                                  // =================================================
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (
                                        int index = 0;
                                        index < days.length;
                                        index++
                                      )
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: index == selectedDayIndex
                                              ? 20
                                              : 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: index == selectedDayIndex
                                                ? AppColors.primary
                                                : AppColors.border,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  Center(
                                    child: Text(
                                      '좌우로 넘겨 날짜별 일정을 확인하세요.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // =================================================
                                  // 날짜별 일정 PageView
                                  //
                                  // 오른쪽 / 왼쪽 스와이프로 날짜 변경
                                  // =================================================
                                  _dayNavigation('top'),
                                  GestureDetector(
                                    onHorizontalDragEnd: (details) {
                                      final velocity =
                                          details.primaryVelocity ?? 0;
                                      if (velocity.abs() < 150) return;
                                      final next =
                                          selectedDayIndex +
                                          (velocity < 0 ? 1 : -1);
                                      if (next >= 0 && next < days.length)
                                        _handleDayChanged(next);
                                    },
                                    child: Column(
                                      key: ValueKey(
                                        'timeline-$selectedDayIndex',
                                      ),
                                      children: [
                                        for (
                                          int index = 0;
                                          index < currentDay.items.length;
                                          index++
                                        )
                                          GestureDetector(
                                            key: _itemKey(index),
                                            onTap: () => _selectItem(index),
                                            child: _TimelineItem(
                                              key: ValueKey(
                                                'timeline-card-$selectedDayIndex-$index',
                                              ),
                                              selected:
                                                  _selectedItemIndex == index,
                                              item: currentDay.items[index],
                                              onMoreTap: () => _showItemMenu(
                                                currentDay,
                                                currentDay.items[index],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _dayNavigation('bottom'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // 하단 저장 / 재추천 영역 유지
              // =================================================
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.bottomCenter,
                child: _showActions
                    ? Container(
                        key: const ValueKey('itinerary-bottom-actions'),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _saveSchedule,
                                  child: Text(
                                    isSaved
                                        ? (_isSaving ? '저장 중…' : '자동 저장됨')
                                        : '일정 저장',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : _regenerateSchedule,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('다시 추천'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 지도 카드
// ===========================================================

class _ItineraryMapCard extends StatelessWidget {
  final Map<int, Uri?> directions;
  final Map<int, Uri?> airportDirections;
  final List<RouteMapPath> paths;
  final LatLng initialTarget;
  final Set<Marker> markers;
  final double height;
  final bool loadTiles;
  final bool pinsVisible;
  final VoidCallback? onTogglePins;
  final int? selectedItemIndex;
  final int selectionRevision;
  final ValueChanged<int>? onItemSelected;
  final ValueChanged<GoogleMapController> onMapCreated;

  const _ItineraryMapCard({
    super.key,
    required this.directions,
    this.height = 240,
    this.loadTiles = true,
    this.pinsVisible = false,
    this.onTogglePins,
    this.selectedItemIndex,
    this.selectionRevision = 0,
    this.onItemSelected,
    this.airportDirections = const {},
    required this.initialTarget,
    required this.paths,
    required this.markers,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: ItineraryRouteMap(
                loadTiles: loadTiles,
                paths: paths,
                selectionRevision: selectionRevision,
                selectedStopIndex: selectedItemIndex == null
                    ? null
                    : (markers.toList()..sort(
                            (a, b) =>
                                int.parse(
                                  a.markerId.value.split('_').last,
                                ).compareTo(
                                  int.parse(b.markerId.value.split('_').last),
                                ),
                          ))
                          .indexWhere(
                            (marker) =>
                                int.parse(
                                  marker.markerId.value.split('_').last,
                                ) ==
                                selectedItemIndex,
                          ),
                onStopSelected: onItemSelected == null
                    ? null
                    : (index) {
                        final sorted = markers.toList()
                          ..sort(
                            (a, b) =>
                                int.parse(
                                  a.markerId.value.split('_').last,
                                ).compareTo(
                                  int.parse(b.markerId.value.split('_').last),
                                ),
                          );
                        onItemSelected!(
                          int.parse(
                            sorted[index].markerId.value.split('_').last,
                          ),
                        );
                      },
                stops:
                    (markers.toList()..sort(
                          (a, b) => int.parse(a.markerId.value.split('_').last)
                              .compareTo(
                                int.parse(b.markerId.value.split('_').last),
                              ),
                        ))
                        .map(
                          (marker) => RouteMapStop(
                            airportAccessUrl:
                                airportDirections[int.parse(
                                  marker.markerId.value.split('_').last,
                                )],
                            directionsToHere:
                                directions[int.parse(
                                  marker.markerId.value.split('_').last,
                                )],
                            useProvidedDirections: true,
                            incomingDirections: true,
                            name: marker.infoWindow.title ?? '방문 장소',
                            detail: marker.infoWindow.snippet ?? '',
                            latitude: marker.position.latitude,
                            longitude: marker.position.longitude,
                          ),
                        )
                        .toList(),
              ),
            ),
            if (onTogglePins != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton.filled(
                  key: const ValueKey('toggle-map-places'),
                  tooltip: pinsVisible ? '장소 목록 접기' : '번호와 장소명 보기',
                  onPressed: onTogglePins,
                  icon: Icon(
                    pinsVisible
                        ? Icons.expand_less
                        : Icons.format_list_numbered,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// 일정 타임라인
// ===========================================================

class _TimelineItem extends StatelessWidget {
  final _ItineraryItem item;
  final VoidCallback onMoreTap;
  final bool selected;
  const _TimelineItem({
    super.key,
    required this.item,
    required this.onMoreTap,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected
            ? AppColors.primary
            : AppColors.border.withValues(alpha: .6),
        width: selected ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.mapNumber != null) ...[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.mapNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  item.time,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.category != '공항' && !item.title.contains('공항'))
                  IconButton(
                    onPressed: onMoreTap,
                    tooltip: '일정 메뉴',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        ItineraryPlaceContent(
          key: ValueKey('content-${item.time}-${item.title}'),
          information: item.displayDescription ?? '',
          movement: item.transportDescription,
          explanation: item.explanation ?? '',
          directionsUrl: item.directionsUrl,
          airportAccessUrl: item.airportAccessUrl,
        ),
      ],
    ),
  );
}

// ===========================================================
// 대체 장소 추천 카드
// ===========================================================

class _PdfActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PdfActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 하단 메뉴 액션
// ===========================================================

class _BottomSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _BottomSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: itemColor),

              const SizedBox(width: 14),

              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 일정 요약 데이터
// ===========================================================

class ItinerarySummary {
  factory ItinerarySummary.fromBackend(
    Map<String, dynamic> request,
    Map<String, dynamic> response,
  ) {
    final cities = (request['cities'] as List? ?? []).join(', ');
    final start =
        DateTime.tryParse(request['startDate']?.toString() ?? '') ??
        DateTime(1970);
    final end =
        DateTime.tryParse(request['endDate']?.toString() ?? '') ??
        start.add(Duration(days: (request['tripDays'] as num).toInt() - 1));
    return ItinerarySummary(
      title:
          request['title']?.toString() ??
          ((request['cities'] as List? ?? []).length > 1
              ? '${(request['cities'] as List).first} ~ ${(request['cities'] as List).last} 여행'
              : '$cities 여행'),
      region: cities,
      period: request['startDate'] == null
          ? '날짜 미정'
          : '${request['startDate']} ~ ${request['endDate']}',
      duration:
          '${end.difference(start).inDays}박 ${end.difference(start).inDays + 1}일',
      theme: (request['themes'] as List? ?? []).join(' / '),
      status: '저장됨',
      isCompleted: false,
    );
  }

  final String title;
  final String region;
  final String period;
  final String duration;
  final String theme;
  final String status;
  final bool isCompleted;

  const ItinerarySummary({
    required this.title,
    required this.region,
    required this.period,
    required this.duration,
    required this.theme,
    required this.status,
    required this.isCompleted,
  });

  factory ItinerarySummary.defaultGenerated() {
    return const ItinerarySummary(
      title: '저장된 일정을 선택하세요',
      region: '',
      period: '',
      duration: '',
      theme: '',
      status: '저장 전',
      isCompleted: false,
    );
  }

  factory ItinerarySummary.fromExtra(Object? extra) {
    if (extra is! Map) {
      return ItinerarySummary.defaultGenerated();
    }

    return ItinerarySummary(
      title: extra['title']?.toString() ?? '도쿄 여행',
      region: extra['region']?.toString() ?? '도쿄',
      period: extra['period']?.toString() ?? '2026-07-02(목)',
      duration: extra['duration']?.toString() ?? '3박 4일',
      theme: extra['theme']?.toString() ?? '식도락 / 쇼핑 / 힐링',
      status: extra['status']?.toString() ?? '저장 전',
      isCompleted: extra['isCompleted'] == true,
    );
  }
}

// ===========================================================
// 날짜별 일정
// ===========================================================

class _ItineraryDay {
  final int dayNumber;
  final String dateLabel;
  final String overview;
  final List<_ItineraryItem> items;

  _ItineraryDay({
    required this.dayNumber,
    required this.dateLabel,
    this.overview = '',
    required this.items,
  });
}

// ===========================================================
// 개별 일정
//
// 지도 표시가 필요한 장소는 latitude / longitude를 가집니다.
// 삭제된 공백 일정은 좌표가 없으므로 지도에 표시되지 않습니다.
// ===========================================================

class _ItineraryItem {
  int? itineraryId;
  final bool walking;
  final bool driving;
  final bool airborne;
  final bool hasTransport;
  final List<List<double>> geometry;
  final String geometrySource;
  Uri? directionsUrl;
  final Uri? airportAccessUrl;
  final String time;
  final String title;
  String description;
  final String? displayDescription;
  final String? explanation;
  final String transportDescription;
  final String category;
  final bool isEmpty = false;
  int? mapNumber;

  final double? latitude;
  final double? longitude;

  _ItineraryItem({
    this.itineraryId,
    this.airportAccessUrl,
    this.walking = false,
    this.driving = false,
    this.airborne = false,
    this.hasTransport = false,
    this.geometry = const [],
    this.geometrySource = "",
    required this.time,
    required this.title,
    required this.description,
    this.displayDescription,
    this.explanation,
    this.transportDescription = "",
    required this.category,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation {
    return !isEmpty && validItineraryLocation(latitude, longitude);
  }

  LatLng? get position {
    if (!hasLocation) {
      return null;
    }

    return LatLng(latitude!, longitude!);
  }
}

// ===========================================================
// 대체 추천 장소
// ===========================================================

class _ItineraryMapHeader extends SliverPersistentHeaderDelegate {
  const _ItineraryMapHeader({required this.extent, required this.child});
  final double extent;
  final Widget child;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant _ItineraryMapHeader oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}
