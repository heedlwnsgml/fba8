import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../services/permission_service.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  Position? _currentPosition;

  bool _isLoadingLocation = false;
  bool _isLocationGranted = false;
  bool _isLocationServiceDisabled = false;
  bool _isPermissionPermanentlyDenied = false;

  String? _locationError;

  // =========================================================
  // 지도 기본 위치
  // 위치 정보를 얻지 못한 경우 주일본 대한민국 대사관을 기준으로 표시
  // =========================================================

  static const LatLng _fallbackLocation = LatLng(35.650743, 139.733680);

  // =========================================================
  // 일본 내 대한민국 대사관 / 총영사관 정보
  //
  // 대표전화 및 주소는 외교부 공개 정보를 기준으로 작성.
  // 좌표는 가장 가까운 공관 계산 및 지도 표시를 위한 고정 좌표이며,
  // 향후 공관 이전 등이 있을 경우 함께 갱신해야 함.
  // =========================================================

  static const List<_KoreanMission> _missions = [
    _KoreanMission(
      name: '주일본 대한민국 대사관',
      phone: '+81-3-3452-7611',
      address: '東京都港区南麻布1-2-5',
      latitude: 35.650743,
      longitude: 139.733680,
    ),
    _KoreanMission(
      name: '주삿포로 대한민국 총영사관',
      phone: '+81-11-218-0288',
      address: '北海道札幌市中央区北2条西12丁目1-4',
      latitude: 43.060746,
      longitude: 141.338700,
    ),
    _KoreanMission(
      name: '주센다이 대한민국 총영사관',
      phone: '+81-22-221-2751',
      address: '宮城県仙台市青葉区上杉1丁目4-3',
      latitude: 38.270900,
      longitude: 140.870000,
    ),
    _KoreanMission(
      name: '주요코하마 대한민국 총영사관',
      phone: '+81-45-621-4531',
      address: '神奈川県横浜市中区山手町118',
      latitude: 35.438755,
      longitude: 139.650934,
    ),
    _KoreanMission(
      name: '주니가타 대한민국 총영사관',
      phone: '+81-25-255-5555',
      address: '新潟市中央区万代島5-1 万代島ビル8階',
      latitude: 37.922519,
      longitude: 139.050851,
    ),
    _KoreanMission(
      name: '주나고야 대한민국 총영사관',
      phone: '+81-52-586-9221',
      address: '愛知県名古屋市中村区名駅南1-19-12',
      latitude: 35.163326,
      longitude: 136.889134,
    ),
    _KoreanMission(
      name: '주오사카 대한민국 총영사관',
      phone: '+81-6-4256-2345',
      address: '大阪府大阪市中央区西心斎橋2-3-4',
      latitude: 34.669193,
      longitude: 135.499476,
    ),
    _KoreanMission(
      name: '주고베 대한민국 총영사관',
      phone: '+81-78-221-4853',
      address: '兵庫県神戸市中央区中山手通2-21-5',
      latitude: 34.697192,
      longitude: 135.187308,
    ),
    _KoreanMission(
      name: '주히로시마 대한민국 총영사관',
      phone: '+81-82-505-2100',
      address: '広島市南区翠5丁目9-17',
      latitude: 34.373631,
      longitude: 132.475575,
    ),
    _KoreanMission(
      name: '주후쿠오카 대한민국 총영사관',
      phone: '+81-92-771-0461',
      address: '福岡市中央区地行浜1-1-3',
      latitude: 33.589616,
      longitude: 130.364283,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCurrentLocation(requestPermission: false);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // =========================================================
  // 현재 위치 및 위치 권한 처리
  // =========================================================

  Future<void> _loadCurrentLocation({bool requestPermission = true}) async {
    if (!mounted || _isLoadingLocation) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;

      _locationError = null;

      _isLocationServiceDisabled = false;
      _isPermissionPermanentlyDenied = false;
    });

    try {
      // 기기의 위치 서비스 활성화 여부 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingLocation = false;
          _isLocationGranted = false;

          _isLocationServiceDisabled = true;

          _locationError =
              '기기의 위치 서비스가 꺼져 있습니다.\n'
              '위치 서비스를 켠 후 다시 시도해 주세요.';
        });

        return;
      }

      // 현재 위치 권한 확인
      var permissionStatus = await PermissionService.getLocationStatus();

      // 아직 허용하지 않은 경우 권한 요청
      if (permissionStatus != PermissionStatus.granted && requestPermission) {
        permissionStatus = await PermissionService.requestLocationPermission();
      }

      if (!mounted) {
        return;
      }

      // 앱 설정에서 직접 위치 권한을 허용해야 하는 경우
      if (permissionStatus == PermissionStatus.permanentlyDenied) {
        setState(() {
          _isLoadingLocation = false;
          _isLocationGranted = false;

          _isPermissionPermanentlyDenied = true;

          _locationError =
              '위치 권한이 차단되어 있습니다.\n'
              '앱 설정에서 위치 권한을 허용해 주세요.';
        });

        return;
      }

      // 일반적인 권한 거부
      if (permissionStatus != PermissionStatus.granted) {
        setState(() {
          _isLoadingLocation = false;
          _isLocationGranted = false;

          _locationError =
              '가장 가까운 대한민국 공관을 확인하려면 '
              '위치 권한이 필요합니다.';
        });

        return;
      }

      // 실제 현재 위치 획득
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;

        _isLocationGranted = true;
        _isLoadingLocation = false;

        _locationError = null;
      });

      // 현재 위치와 가장 가까운 공관이 모두 보이도록 지도 이동
      await _moveCameraToRelevantArea();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _isLocationGranted = false;

        _locationError =
            '현재 위치를 불러오지 못했습니다.\n'
            '잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // =========================================================
  // 현재 위치에서 가장 가까운 대한민국 공관 계산
  // =========================================================

  _KoreanMission? _getNearestMission() {
    final position = _currentPosition;

    if (position == null) {
      return null;
    }

    _KoreanMission? nearestMission;
    double nearestDistance = double.infinity;

    for (final mission in _missions) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        mission.latitude,
        mission.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestMission = mission;
      }
    }

    return nearestMission;
  }

  // =========================================================
  // 현재 위치와 특정 공관 사이의 거리 계산
  // =========================================================

  double? _getMissionDistanceMeters(_KoreanMission mission) {
    final position = _currentPosition;

    if (position == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      mission.latitude,
      mission.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }

    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  // =========================================================
  // 지도 카메라 이동
  //
  // 현재 위치와 가장 가까운 대한민국 공관이
  // 한 화면에 들어오도록 자동 조절
  // =========================================================

  Future<void> _moveCameraToRelevantArea() async {
    if (!_mapReady || !mounted) return;
    final position = _currentPosition;
    final mission = _getNearestMission();
    if (position == null || mission == null) return;
    final user = LatLng(position.latitude, position.longitude);
    final embassy = LatLng(mission.latitude, mission.longitude);
    if ((user.latitude - embassy.latitude).abs() < 0.005 &&
        (user.longitude - embassy.longitude).abs() < 0.005) {
      _mapController.move(user, 14);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [user, embassy],
          padding: const EdgeInsets.all(48),
          maxZoom: 14,
        ),
      );
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await PermissionService.openAppPermissionSettings();
  }

  // =========================================================
  // 가장 가까운 대한민국 공관 지도 마커
  // =========================================================

  List<Marker> _buildMissionMarkers() {
    final mission = _getNearestMission() ?? _missions.first;
    return [
      Marker(
        point: LatLng(mission.latitude, mission.longitude),
        width: 48,
        height: 48,
        child: Tooltip(
          message: '${mission.name}\n${mission.phone}',
          child: const Icon(
            Icons.location_on,
            color: AppColors.emergency,
            size: 42,
          ),
        ),
      ),
      if (_isLocationGranted && _currentPosition != null)
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 32,
          height: 32,
          child: const Tooltip(
            message: '현재 위치',
            child: Icon(Icons.my_location, color: Colors.blue, size: 28),
          ),
        ),
    ];
  }

  Widget _buildMapPreview() {
    final position = _currentPosition;

    final initialTarget = position == null
        ? _fallbackLocation
        : LatLng(position.latitude, position.longitude);

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFC9C9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialTarget,
                  initialZoom: 12,
                  onMapReady: () {
                    _mapReady = true;
                    _moveCameraToRelevantArea();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aiplanner.ai_travel_planner',
                  ),
                  MarkerLayer(markers: _buildMissionMarkers()),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 지도 우측 상단 위치 다시 맞추기 버튼
            Positioned(
              top: 14,
              right: 14,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isLoadingLocation
                      ? null
                      : () async {
                          if (_currentPosition == null) {
                            await _loadCurrentLocation();
                          } else {
                            await _moveCameraToRelevantArea();
                          }
                        },
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.emergency,
                    ),
                  ),
                ),
              ),
            ),

            // 현재 위치 확인 중
            if (_isLoadingLocation)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.emergency,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '현재 위치를 확인하고 있습니다.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // 위치 확인 성공
            else if (_currentPosition != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppColors.emergency,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '내 위치와 가장 가까운 대한민국 공관',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // 위치 오류
            else if (_locationError != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            color: AppColors.emergency,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationError!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (_isLocationServiceDisabled) {
                              await _openLocationSettings();
                            } else if (_isPermissionPermanentlyDenied) {
                              await _openAppSettings();
                            } else {
                              await _loadCurrentLocation();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.emergency,
                            side: const BorderSide(color: AppColors.emergency),
                          ),
                          child: Text(
                            _isLocationServiceDisabled
                                ? '위치 설정 열기'
                                : _isPermissionPermanentlyDenied
                                ? '앱 설정 열기'
                                : '다시 시도',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 사용자 현재 위치 위도 / 경도
  // =========================================================

  Widget _buildCurrentLocationInfo() {
    final position = _currentPosition;

    if (_isLoadingLocation) {
      return const SizedBox.shrink();
    }

    if (position == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.my_location_rounded,
            color: AppColors.emergency,
            size: 20,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 위치',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '위도 ${position.latitude.toStringAsFixed(6)}  ·  '
                  '경도 ${position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 세 번째 카드:
  // 현재 위치 기준 가장 가까운 대한민국 대사관 / 총영사관
  // =========================================================

  Widget _buildNearestMissionCard() {
    if (_isLoadingLocation) {
      return const _LoadingMissionCard();
    }

    final mission = _getNearestMission();

    if (mission == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '대한민국 공관 연락처',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadCurrentLocation,
            child: const Text('위치 권한으로 가까운 공관 찾기'),
          ),
          if (_locationError != null) Text(_locationError!),
          for (final contact in _missions) ...[
            const SizedBox(height: 10),
            _MissionCard(mission: contact, distanceText: null),
          ],
        ],
      );
    }

    return _MissionCard(
      mission: mission,
      distanceText: _getMissionDistanceMeters(mission) == null
          ? null
          : _formatDistance(_getMissionDistanceMeters(mission)!),
    );
  }

  // =========================================================
  // 화면 구성
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emergencyBackground,

      endDrawer: const AppDrawer(currentRoute: AppRoutes.emergency),

      body: SafeArea(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: '긴급 연락 안내',
                    onMenuTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    '일본에서 필요한\n긴급 연락처를 확인하세요.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '소방·구급과 경찰 긴급번호를 확인하고, '
                    '현재 위치에서 가장 가까운 대한민국 '
                    '대사관 또는 총영사관 정보를 확인할 수 있습니다.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 현재 위치와 가장 가까운 공관 지도
                  _buildMapPreview(),

                  const SizedBox(height: 14),

                  // 현재 위치 위도 / 경도
                  _buildCurrentLocationInfo(),

                  const SizedBox(height: 26),

                  Text(
                    '긴급 연락처',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 1. 일본 전역 공통 소방 / 구급 번호
                  const _EmergencyNumberCard(
                    number: '119',
                    title: '소방·구급',
                    description: '화재 또는 응급환자가 발생한 경우',
                    icon: Icons.local_fire_department_rounded,
                  ),

                  // 2. 일본 전역 공통 경찰 번호
                  const _EmergencyNumberCard(
                    number: '110',
                    title: '경찰',
                    description: '사건·사고 등 긴급한 경찰 신고가 필요한 경우',
                    icon: Icons.local_police_rounded,
                  ),

                  // 3. 현재 위치에서 가장 가까운 대한민국 공관
                  _buildNearestMissionCard(),

                  const SizedBox(height: 6),

                  const Text(
                    '대한민국 공관 정보는 외교부 공개 정보를 기준으로 합니다. '
                    '공관 연락처와 위치는 변경될 수 있습니다.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================
// 대한민국 대사관 / 총영사관 데이터 모델
// ===========================================================

class _KoreanMission {
  final String name;
  final String phone;
  final String address;

  final double latitude;
  final double longitude;

  const _KoreanMission({
    required this.name,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

// ===========================================================
// 일본 전역 공통 긴급번호 카드
// 소방·구급 119 / 경찰 110
// ===========================================================

class _EmergencyNumberCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _EmergencyNumberCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.emergency.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.emergency, size: 30),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        color: AppColors.emergency,
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                      ),
                    ),

                    const SizedBox(width: 10),

                    const Text(
                      '일본 전역 공통',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 가장 가까운 대한민국 공관 카드
// ===========================================================

class _MissionCard extends StatelessWidget {
  final _KoreanMission mission;
  final String? distanceText;

  const _MissionCard({required this.mission, required this.distanceText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.emergency.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.emergency,
                  size: 29,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '가장 가까운 대한민국 공관',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      mission.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),

                    if (distanceText != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '현재 위치에서 약 $distanceText',
                        style: const TextStyle(
                          color: AppColors.emergency,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _MissionInfoRow(
            icon: Icons.call_rounded,
            label: '대표전화',
            value: mission.phone,
          ),

          const SizedBox(height: 12),

          _MissionInfoRow(
            icon: Icons.location_on_outlined,
            label: '주소',
            value: mission.address,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 공관 카드 내부 정보 행
// ===========================================================

class _MissionInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MissionInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.emergency, size: 20),

        const SizedBox(width: 10),

        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// 가장 가까운 공관 계산 중 표시
// ===========================================================

class _LoadingMissionCard extends StatelessWidget {
  const _LoadingMissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.emergency,
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Text(
              '현재 위치에서 가장 가까운 대한민국 공관을 찾고 있습니다.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 위치 확인 실패 시 세 번째 카드
// ===========================================================

class _MissionUnavailableCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MissionUnavailableCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_rounded, color: AppColors.emergency),

              SizedBox(width: 10),

              Text(
                '가장 가까운 대한민국 공관',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('위치 다시 확인'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emergency,
                side: const BorderSide(color: AppColors.emergency),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
