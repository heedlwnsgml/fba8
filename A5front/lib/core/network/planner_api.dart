import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../state/trip_draft.dart';
import '../services/generation_background.dart';
import '../state/money_display.dart';

String plannerUserMessage(String message) =>
    RegExp(r'\bAPI\b', caseSensitive: false).hasMatch(message)
    ? '정보를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'
    : message;

class PlannerApiException implements Exception {
  const PlannerApiException(this.message, {this.retryable = false});
  final bool retryable;
  final String message;
  @override
  String toString() => plannerUserMessage(message);
}

class GenerationTask {
  GenerationTask(this.id, this.request, this.revision);
  final String id;
  final Map<String, dynamic> request;
  final int revision;
  final submitted = Completer<void>();
  String status = 'QUEUED';
  String message = '생성 요청을 보내고 있습니다.';
  String? error;
  Map<String, dynamic>? result;
  Map<String, dynamic>? endTimeApproval;
  bool get active =>
      status == 'QUEUED' ||
      status == 'RUNNING' ||
      status == 'CANCELLING' ||
      status == 'WAITING_APPROVAL';
  String get title => request['title']?.toString() ?? '여행 일정';
}

/// Android는 날씨 알림용 세션을 Keystore로 암호화해 복원합니다. 다른 플랫폼은 메모리에 보관합니다.
class PlannerApi extends ChangeNotifier {
  PlannerApi({
    Dio? dio,
    this.generationPollInterval = const Duration(seconds: 2),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: defaultBaseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(minutes: 3),
               headers: {'Content-Type': 'application/json'},
             ),
           );

  static final instance = PlannerApi();
  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  final money = MoneyDisplay();
  final Dio _dio;
  final Duration generationPollInterval;
  String? _generationFingerprint, _generationId;
  String? _token;
  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;
  int _plansRevision = 0;
  int get plansRevision => _plansRevision;
  bool get isLoggedIn => _token != null;
  bool _viewAsUser = false;
  bool get viewAsUser => _viewAsUser;
  bool get showAdminInformation => isAdmin && !_viewAsUser;
  void setViewAsUser(bool value) {
    if (!isAdmin || _viewAsUser == value) return;
    _viewAsUser = value;
    final key = _adminViewKey;
    if (key != null)
      unawaited(
        SharedPreferences.getInstance()
            .then((prefs) async {
              await prefs.setBool(key, value);
            })
            .catchError((Object _) {}),
      );
    notifyListeners();
  }

  String? get _adminViewKey {
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(_token!.split('.')[1])),
                ),
              )
              as Map;
      final subject = claims['sub']?.toString();
      if (subject == null || subject.isEmpty) return null;
      return 'admin_view_v1_${base64Url.encode(utf8.encode('$baseUrl|$subject'))}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreAdminView() async {
    final revision = sessionRevision, key = _adminViewKey;
    if (!isAdmin || key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision == sessionRevision)
        _viewAsUser = prefs.getBool(key) ?? false;
    } catch (_) {}
  }

  bool get isAdmin {
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(_token!.split('.')[1])),
                ),
              )
              as Map;
      return claims['role'] == 'ADMIN';
    } catch (_) {
      return false;
    }
  }

  Future<String> getHotelCurrencyPreference() async {
    _requireLogin();
    final revision = sessionRevision;
    final value = _asMap(
      await _request('GET', '/api/v1/account/preferences', authenticated: true),
    );
    final currency = value['hotelBudgetCurrency'] == 'JPY' ? 'JPY' : 'KRW';
    if (revision != sessionRevision)
      throw const PlannerApiException('계정이 변경되었습니다.');
    TripDraft.instance.defaultHotelBudgetCurrency = currency;
    money.configure(currency: currency);
    return currency;
  }

  Future<void> saveHotelCurrencyPreference(String currency) async {
    _requireLogin();
    if (!['KRW', 'JPY'].contains(currency))
      throw const PlannerApiException('원 또는 엔을 선택하세요.');
    final revision = sessionRevision;
    await _request(
      'PUT',
      '/api/v1/account/preferences',
      authenticated: true,
      data: {'hotelBudgetCurrency': currency},
    );
    if (revision != sessionRevision)
      throw const PlannerApiException('계정이 변경되었습니다.');
    TripDraft.instance.defaultHotelBudgetCurrency = currency;
    money.configure(currency: currency);
  }

  Future<Map<String, dynamic>> getLiveDirections(Uri route) async {
    _requireLogin();
    return _asMap(
      await _request(
        'POST',
        '/api/v1/routes/live',
        authenticated: true,
        data: {
          'origin': route.queryParameters['origin'],
          'destination': route.queryParameters['destination'],
          'mode': route.queryParameters['travelmode'] ?? 'transit',
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getExchangeRate() async {
    _requireLogin();
    final revision = sessionRevision;
    final value = _asMap(
      await _request(
        'GET',
        '/api/v1/exchange-rates/jpy-krw',
        authenticated: true,
      ),
    );
    if (revision != sessionRevision)
      throw const PlannerApiException('계정이 변경되었습니다.');
    money.configure(rate: value['krwPerJpy'] as num?);
    return value;
  }

  Future<void> saveExchangeRate(Map<String, dynamic> rate) async {
    await _request(
      'POST',
      '/api/v1/admin/exchange-rates/jpy-krw',
      data: rate,
      authenticated: true,
    );
  }

  String get baseUrl => _dio.options.baseUrl;

  static const _weatherChannel = MethodChannel('ai_travel_planner/weather');
  int _weatherRevision = 0;
  int get weatherRevision => _weatherRevision;
  String? get weatherSessionToken => _token;
  Future<void> restoreWeatherSession() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final data = await _weatherChannel.invokeMapMethod<String, dynamic>(
        'getSession',
      );
      if (data?['baseUrl'] == baseUrl && data?['token'] is String) {
        _token = data!['token'] as String;
        _sessionRevision++;
        await _restoreAdminView();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getLongTripSettings() async => _asMap(
    await _request(
      'GET',
      '/api/v1/users/me/long-trip-settings',
      authenticated: true,
    ),
  );
  Future<Map<String, dynamic>> updateLongTripSettings(
    Map<String, dynamic> settings,
  ) async => _asMap(
    await _request(
      'PUT',
      '/api/v1/users/me/long-trip-settings',
      data: settings,
      authenticated: true,
    ),
  );

  Future<Map<String, dynamic>> getWeatherSettings() async => _asMap(
    await _request('GET', '/api/v1/weather/settings', authenticated: true),
  );
  Future<List<Map<String, dynamic>>> getWeatherAlerts() async =>
      (await _request('GET', '/api/v1/weather/alerts', authenticated: true)
              as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<void> updateWeatherSettings(Map<String, dynamic> settings) async {
    await _request(
      'PUT',
      '/api/v1/weather/settings',
      data: settings,
      authenticated: true,
    );
    _weatherRevision++;
    notifyListeners();
  }

  void setBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const PlannerApiException('주소는 http://호스트:포트 형식으로 입력하세요.');
    }
    final normalized = uri.toString().replaceFirst(RegExp(r'/$'), '');
    if (normalized != baseUrl) logout();
    _dio.options.baseUrl = normalized;
  }

  void logout() {
    unawaited(GenerationBackground.clear());
    _token = null;
    _viewAsUser = false;
    money.reset();
    _generationId = null;
    _generationFingerprint = null;
    _tasks.clear();
    _sessionRevision++;
    TripDraft.instance.defaultHotelBudgetCurrency = 'KRW';
    TripDraft.instance.resetInputs();
    TripDraft.instance.lastGenerated = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getProfile() async {
    _requireLogin();
    return _asMap(
      await _request('GET', '/api/v1/auth/me', authenticated: true),
    );
  }

  Future<Map<String, dynamic>> updateName(String value) async {
    _requireLogin();
    final name = value.trim();
    if (name.isEmpty || name.length > 40)
      throw const PlannerApiException('이름은 1~40자로 입력하세요.');
    return _asMap(
      await _request(
        'PATCH',
        '/api/v1/auth/me',
        data: {'displayName': name},
        authenticated: true,
      ),
    );
  }

  Future<void> withdraw() async {
    _requireLogin();
    await _request('POST', '/api/v1/auth/withdraw', authenticated: true);
    logout();
  }

  Future<List<Map<String, dynamic>>> listPlans() async {
    _requireLogin();
    final data = await _request('GET', '/api/v1/plans', authenticated: true);
    if (data is! List) throw const PlannerApiException('일정 목록 응답을 확인하세요.');
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deletePlan(int id) async {
    _requireLogin();
    await _request('DELETE', '/api/v1/plans/$id', authenticated: true);
    notifyListeners();
  }

  Future<Map<String, dynamic>> getPlan(int id) async {
    _requireLogin();
    final data = await _request(
      'GET',
      '/api/v1/plans/$id',
      authenticated: true,
    );
    if (data is! Map) throw const PlannerApiException('일정 상세 응답을 확인하세요.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> beginSocialLogin(String provider) async =>
      _asMap(
        await _request(
          'POST',
          '/api/v1/auth/oauth/begin',
          data: {'provider': provider},
        ),
      );
  Future<void> cancelSocialLogin(Map<String, dynamic> ticket) async {
    await _request(
      'POST',
      '/api/v1/auth/oauth/cancel',
      data: {'id': ticket['id'], 'secret': ticket['secret']},
    );
  }

  Future<bool> pollSocialLogin(
    Map<String, dynamic> ticket, {
    required int revision,
    bool Function()? isActive,
  }) async {
    final result = _asMap(
      await _request(
        'POST',
        '/api/v1/auth/oauth/poll',
        data: {'id': ticket['id'], 'secret': ticket['secret']},
      ),
    );
    if (revision != sessionRevision || (isActive != null && !isActive()))
      throw const PlannerApiException('로그인 상태가 변경되어 소셜 로그인을 취소했습니다.');
    if (result['status'] == 'FAILED')
      throw PlannerApiException(result['message']?.toString() ?? '소셜 로그인 실패');
    if (result['status'] != 'SUCCEEDED') return false;
    final token = result['token']?.toString() ?? '';
    if (!RegExp(
      r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
    ).hasMatch(token))
      throw const PlannerApiException('로그인 응답을 확인하세요.');
    _token = token;
    _sessionRevision++;
    await _restoreAdminView();
    notifyListeners();
    return true;
  }

  Future<String> signup({
    required String email,
    required String password,
    required String gender,
    required String ageGroup,
  }) async {
    final response = await _request(
      'POST',
      '/api/v1/auth/signup',
      data: {
        'email': email.trim(),
        'password': password,
        'gender': gender,
        'ageGroup': ageGroup,
      },
    );
    return response.toString();
  }

  Future<void> login(String email, String password) async {
    logout();
    final response = await _request(
      'POST',
      '/api/v1/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    // 기존 백엔드는 토큰과 로그인 실패 문구 모두 문자열로 반환합니다.
    final token = response?.toString().trim() ?? '';
    if (!RegExp(
      r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
    ).hasMatch(token)) {
      throw PlannerApiException(token.isEmpty ? '로그인 응답이 비어 있습니다.' : token);
    }
    _token = token;
    _sessionRevision++;
    await _restoreAdminView();
    notifyListeners();
  }

  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    _requireLogin();
    final cities = plan['cities'];
    if (cities is! List || cities.isEmpty) {
      throw const PlannerApiException('cities에 도시를 하나 이상 입력하세요.');
    }
    final start = DateTime.tryParse(plan['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(plan['endDate']?.toString() ?? '');
    final nights = start != null && end != null
        ? end.difference(start).inDays
        : (plan['tripDays'] as num).toInt() - 1;
    if (nights < 0) throw const PlannerApiException('종료일이 시작일보다 빠릅니다.');
    return _asMap(
      await _request(
        'GET',
        '/api/v1/plans/validate',
        query: {
          'selectedCities': cities.join(','),
          'inCity': plan['inCity'],
          'outCity': plan['outCity'],
          'nights': nights,
        },
        authenticated: true,
      ),
    );
  }

  final Map<String, GenerationTask> _tasks = {};
  List<GenerationTask> get generationTasks =>
      _tasks.values.where((t) => t.revision == _sessionRevision).toList();
  GenerationTask startGeneration(Map<String, dynamic> request) {
    _requireLogin();
    if (generationTasks.where((t) => t.active).length >= 2) {
      throw const PlannerApiException('일정은 한 번에 최대 2개까지 생성할 수 있습니다.');
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final task = GenerationTask(
      id,
      Map<String, dynamic>.from(jsonDecode(jsonEncode(request)) as Map),
      _sessionRevision,
    );
    _tasks[id] = task;
    notifyListeners();
    unawaited(_runGeneration(task));
    return task;
  }

  Future<void> _runGeneration(GenerationTask task) async {
    final token = _token!;
    try {
      unawaited(
        GenerationBackground.watch(
          id: task.id,
          title: task.title,
          baseUrl: baseUrl,
          token: token,
        ),
      );
      if (task.revision != _sessionRevision) return;
      final response = await createPlan(
        task.request,
        requestId: task.id,
        submissionPath: task.request['researchPlanId'] is num
            ? '/api/v1/plans/${task.request['researchPlanId']}/transport-research'
            : null,
        onSubmitted: () {
          if (!task.submitted.isCompleted) task.submitted.complete();
        },
        onApproval: (approval) {
          if (task.revision != _sessionRevision || task.status == 'CANCELLED')
            return;
          task.endTimeApproval = approval;
          if (approval != null && task.status != 'CANCELLING')
            task.status = 'WAITING_APPROVAL';
          notifyListeners();
        },
        onProgress: (message) {
          if (task.status == 'CANCELLED') return;
          if (task.status != 'CANCELLING')
            task.status = task.endTimeApproval == null
                ? 'RUNNING'
                : 'WAITING_APPROVAL';
          task.message = plannerUserMessage(message);
          notifyListeners();
        },
      );
      if (task.revision != _sessionRevision) return;
      task.result = {'response': response, 'request': task.request};
      task.status = 'SUCCEEDED';
      _plansRevision++;
      TripDraft.instance.lastGenerated = task.result;
    } catch (e) {
      if (task.status != 'CANCELLED') {
        task.status = 'FAILED';
        task.error = e.toString();
      }
    } finally {
      if (!task.submitted.isCompleted) task.submitted.complete();
      if (task.revision == _sessionRevision) {
        unawaited(
          GenerationBackground.finish(
            id: task.id,
            title: task.title,
            token: token,
            status: task.status,
            planId: (task.result?['response'] as Map?)?['planId'],
          ),
        );
        notifyListeners();
      }
    }
  }

  Future<void> decideGenerationEndTime(
    String id,
    String decisionId,
    bool allow,
  ) async {
    _requireLogin();
    final task = _tasks[id];
    final revision = _sessionRevision;
    if (task == null || task.revision != revision || !task.active)
      throw const PlannerApiException('현재 선택을 기다리는 생성 작업이 아닙니다.');
    await _request(
      'POST',
      '/api/v1/plans/generation-jobs/$id/end-time-decision',
      data: {'decisionId': decisionId, 'allow': allow},
      authenticated: true,
      requestTimeout: const Duration(seconds: 15),
    );
    if (revision != _sessionRevision) return;
    task.endTimeApproval = null;
    if (task.active) {
      task.status = 'RUNNING';
      task.message = allow
          ? '해당 일차의 종료 시각 초과를 반영하고 있습니다.'
          : '종료 시각 안에 맞는 대안을 찾고 있습니다.';
    }
    notifyListeners();
  }

  Future<GenerationTask> resumeGenerationJob(String id) async {
    _requireLogin();
    final existing = _tasks[id];
    if (existing != null && existing.revision == _sessionRevision)
      return existing;
    final revision = _sessionRevision;
    final request = _asMap(
      await _request(
        'GET',
        '/api/v1/plans/generation-jobs/$id/request',
        authenticated: true,
      ),
    );
    if (revision != _sessionRevision)
      throw const PlannerApiException('로그인 계정이 변경되었습니다.');
    final attached = _tasks[id];
    if (attached != null && attached.revision == revision) return attached;
    if (generationTasks.where((t) => t.active).length >= 2)
      throw const PlannerApiException('일정은 한 번에 최대 2개까지 생성할 수 있습니다.');
    final task = GenerationTask(id, request, revision);
    _tasks[id] = task;
    notifyListeners();
    unawaited(_runGeneration(task));
    return task;
  }

  Future<void> cancelGeneration(String id) async {
    _requireLogin();
    final task = _tasks[id];
    if (task == null || task.revision != _sessionRevision || !task.active)
      return;
    await task.submitted.future.timeout(const Duration(seconds: 25));
    if (!task.active) return;
    final result = _asMap(
      await _request(
        'DELETE',
        '/api/v1/plans/generation-jobs/$id',
        authenticated: true,
        requestTimeout: const Duration(seconds: 15),
      ),
    );
    if (result['status'] == 'CANCELLED') {
      task.status = result['cancellationPending'] == true
          ? 'CANCELLING'
          : 'CANCELLED';
      task.message = '생성을 취소했습니다.';
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createPlan(
    Map<String, dynamic> plan, {
    void Function(String)? onProgress,
    void Function(Map<String, dynamic>?)? onApproval,
    String? requestId,
    void Function()? onSubmitted,
    String? submissionPath,
  }) async {
    _requireLogin();
    final fingerprint = jsonEncode(plan);
    if (requestId == null &&
        (_generationId == null || _generationFingerprint != fingerprint)) {
      final random = Random.secure();
      _generationId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _generationFingerprint = fingerprint;
    }
    final id = requestId ?? _generationId!;
    final revision = _sessionRevision;
    Map<String, dynamic>? job;
    bool submitted = false;
    while (true) {
      if (_tasks[id]?.status == 'CANCELLED')
        throw const PlannerApiException('생성을 취소했습니다.');
      if (revision != _sessionRevision)
        throw const PlannerApiException('로그인 계정이 변경되었습니다. 다시 로그인하세요.');
      try {
        job = _asMap(
          await _request(
            submitted ? 'GET' : 'POST',
            submitted
                ? '/api/v1/plans/generation-jobs/$id'
                : submissionPath ?? '/api/v1/plans/generation-jobs',
            data: submitted ? null : {...plan, 'clientRequestId': id},
            authenticated: true,
            requestTimeout: const Duration(seconds: 20),
          ),
        );
        if (_tasks[id]?.status == 'CANCELLED')
          throw const PlannerApiException('생성을 취소했습니다.');
        submitted = true;
        onSubmitted?.call();
        onApproval?.call(
          job['status'] == 'WAITING_APPROVAL' && job['approval'] is Map
              ? _asMap(job['approval'])
              : null,
        );
        switch (job['status']) {
          case 'SUCCEEDED':
            final response = _asMap(job['response']);
            if (response['timeline'] is! List ||
                (response['timeline'] as List).isEmpty)
              throw const PlannerApiException('생성된 일정이 비어 있습니다. 여행 조건을 조정하세요.');
            _generationId = null;
            _generationFingerprint = null;
            notifyListeners();
            return response;
          case 'CANCELLED':
            if (job['cancellationPending'] == true) {
              onProgress?.call('서버에서 취소를 마무리하고 있습니다.');
            } else {
              if (_tasks[id] != null) _tasks[id]!.status = 'CANCELLED';
              throw const PlannerApiException('생성을 취소했습니다.');
            }
          case 'FAILED':
            _generationId = null;
            _generationFingerprint = null;
            throw PlannerApiException(
              job['error']?.toString() ?? '일정 생성에 실패했습니다.',
            );
          case 'NOT_FOUND':
            submitted = false;
            onProgress?.call('서버가 다시 시작되어 같은 생성 요청을 확인하고 있습니다.');
          case 'QUEUED':
            onProgress?.call('일정 생성 순서를 기다리고 있습니다.');
          case 'WAITING_APPROVAL':
            onProgress?.call(
              job['message']?.toString() ?? '종료 시각 초과 허용 여부를 선택해주세요.',
            );
          case 'RUNNING':
            onProgress?.call(
              job['message']?.toString() ?? '서버에서 동선과 이동 정보를 계산하고 있습니다.',
            );
          default:
            throw const PlannerApiException('일정 생성 상태 응답을 확인하세요.');
        }
      } on PlannerApiException catch (error) {
        if (!error.retryable) rethrow;
        onProgress?.call('서버 연결을 다시 확인하고 있습니다. 생성 결과를 이어서 조회합니다.');
      }
      await Future<void>.delayed(generationPollInterval);
    }
  }

  Future<Map<String, dynamic>> regeneratePlan(
    int id,
    Map<String, dynamic> request,
  ) async {
    _requireLogin();
    final result = _asMap(
      await _request(
        'POST',
        '/api/v1/plans/$id/regenerate',
        data: request,
        authenticated: true,
      ),
    );
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> deletePlanItem(int id, int itemId) async {
    _requireLogin();
    final result = _asMap(
      await _request(
        'DELETE',
        '/api/v1/plans/$id/items/$itemId',
        authenticated: true,
      ),
    );
    notifyListeners();
    return result;
  }

  Future<List<Map<String, dynamic>>> planItemAlternatives(
    int id,
    int itemId, {
    Map<String, String> preferences = const {},
  }) async {
    _requireLogin();
    final result = await _request(
      'POST',
      '/api/v1/plans/$id/items/$itemId/alternatives',
      data: preferences,
      authenticated: true,
    );
    if (result is! List) throw const PlannerApiException('대체 장소 응답을 확인하세요.');
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> replacePlanItem(
    int id,
    int itemId,
    String placeId, {
    Map<String, String> preferences = const {},
  }) async {
    _requireLogin();
    final result = _asMap(
      await _request(
        'PATCH',
        '/api/v1/plans/$id/items/$itemId',
        data: {...preferences, 'placeId': placeId},
        authenticated: true,
      ),
    );
    notifyListeners();
    return result;
  }

  void _requireLogin() {
    if (!isLoggedIn) throw const PlannerApiException('먼저 로그인하세요.');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) throw const PlannerApiException('서버 응답이 JSON 객체가 아닙니다.');
    return Map<String, dynamic>.from(value);
  }

  Future<Response<dynamic>> _sendWithConnectionRecovery(
    String method,
    String path,
    dynamic data,
    Map<String, dynamic>? query,
    Options options,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.request<dynamic>(
          path,
          data: data,
          queryParameters: query,
          options: options,
        );
      } on DioException catch (error) {
        final disconnected =
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout;
        // Retry reads only. Never duplicate a submitted write after a broken connection.
        if (method != 'GET' || !disconnected || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authenticated = false,
    Duration? requestTimeout,
  }) async {
    final revision = _sessionRevision;
    try {
      final response = await _sendWithConnectionRecovery(
        method,
        path,
        data,
        query,
        Options(
          method: method,
          receiveTimeout: requestTimeout,
          headers: {if (authenticated) 'Authorization': 'Bearer $_token'},
        ),
      );
      if (authenticated && revision != _sessionRevision)
        throw const PlannerApiException('로그인 계정이 변경되었습니다. 다시 조회하세요.');
      if (authenticated &&
          method != 'GET' &&
          path.startsWith('/api/v1/plans/') &&
          !path.contains('/generation-jobs') &&
          !path.contains('/transport-research'))
        _plansRevision++;
      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (kDebugMode) {
        // Log request metadata only; never tokens, payloads or query strings.
        debugPrint(
          '[PlannerConnection] $method $path '
          'type=${e.type.name} status=$status host=$baseUrl '
          'cause=${e.error.runtimeType}',
        );
      }
      if (status == 401) {
        if (revision == _sessionRevision) logout();
        throw const PlannerApiException('인증에 실패했습니다. 다시 로그인하세요.');
      }
      if (status == 404 && path.startsWith('/api/v1/plans/generation-jobs')) {
        throw const PlannerApiException(
          '일정 생성 서비스를 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
      final body = e.response?.data;
      final message = body is Map ? body['message'] ?? body['detail'] : body;
      if (message is String && message.isNotEmpty) {
        throw PlannerApiException('HTTP ${status ?? "오류"}: $message');
      }
      if (status != null) throw PlannerApiException('서버 응답 오류: HTTP $status');
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout)
        throw const PlannerApiException(
          '서버 응답 대기 시간이 초과됐습니다. 서버 작업이 끝났는지 다시 확인하세요.',
          retryable: true,
        );
      if (e.type == DioExceptionType.connectionTimeout) {
        throw PlannerApiException(
          '서버 연결 시간이 초과됐습니다. 접속 주소: $baseUrl',
          retryable: true,
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw PlannerApiException(
          '서버 연결을 열지 못했습니다. 접속 주소: $baseUrl',
          retryable: true,
        );
      }
      if (e.type == DioExceptionType.cancel) {
        throw const PlannerApiException('요청이 취소되었습니다.');
      }
      if (e.type == DioExceptionType.badCertificate) {
        throw const PlannerApiException('서버 보안 인증서를 확인하지 못했습니다.');
      }
      throw const PlannerApiException('서버와 통신 중 응답을 처리하지 못했습니다. 다시 시도해 주세요.');
    }
  }
}
