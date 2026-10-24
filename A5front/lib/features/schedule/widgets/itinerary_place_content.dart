import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import 'directions_preview.dart';
import 'transport_details.dart';

/// Shared presentation for a timeline card and the matching map pin sheet.
class ItineraryPlaceContent extends StatelessWidget {
  const ItineraryPlaceContent({
    super.key,
    required this.information,
    required this.movement,
    required this.explanation,
    this.directionsUrl,
    this.airportAccessUrl,
  });
  final String information, movement, explanation;
  final Uri? directionsUrl;
  final Uri? airportAccessUrl;

  static const fields = [
    '체류시간',
    '주소',
    '전화번호',
    '영업시간',
    '영업일',
    '휴무일',
    '평균 숙박요금',
    '1박 최저가',
    '숙박비',
    '숙박비 기준',
    '식사 장소 유형',
    '공항 내 이동',
    '숙박요금 비교',
  ];
  static Map<String, String> parseInformation(String text) {
    final result = <String, String>{};
    String? previous;
    for (final line in text.split('\n').where((s) => s.trim().isNotEmpty)) {
      final split = line.indexOf(':');
      final key = split < 0 ? '' : line.substring(0, split).trim();
      if (fields.contains(key)) {
        previous = key;
        result[key] = line.substring(split + 1).trim();
      } else if (previous != null) {
        result[previous] = '${result[previous]}\n$line';
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final info = parseInformation(information);
    final lines = movement
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final summaries = lines.where((s) => s.startsWith('이동:')).toList();
    final fares = lines.where((s) => s.startsWith('교통비:')).toList();
    final details = lines
        .where((s) => !summaries.contains(s) && !fares.contains(s))
        .join('\n');
    final description = explanation.replaceFirst(RegExp(r'^설명:\s*'), '').trim();
    final extra = Map<String, String>.from(info)
      ..removeWhere(
        (key, _) => [
          '체류시간',
          '영업시간',
          '영업일',
          '휴무일',
          '식사 장소 유형',
          '공항 내 이동',
          '1박 최저가',
          '숙박비',
          '숙박요금 비교',
        ].contains(key),
      );
    extra.remove('1박 최저가');
    final fareText = fares
        .map((s) => s.replaceFirst(RegExp(r'^교통비:\s*'), ''))
        .join('\n');
    final metrics = <Widget>[
      if (info['숙박비']?.isNotEmpty == true)
        _Metric(icon: Icons.hotel_outlined, label: '숙박비', value: info['숙박비']!),
      if (info['1박 최저가']?.isNotEmpty == true)
        _Metric(
          icon: Icons.hotel_outlined,
          label: '1박 최저가',
          value: info['1박 최저가']!,
        ),
      if (info['체류시간']?.isNotEmpty == true)
        _Metric(
          icon: Icons.schedule_rounded,
          label: '체류시간',
          value: info['체류시간']!,
        ),
      if (fareText.isNotEmpty)
        _Metric(icon: Icons.payments_outlined, label: '이동 요금', value: fareText),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summaries.isNotEmpty) ...[
          const Text(
            '이 장소까지 오는 방법',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        if (summaries.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _transportIcon(movement),
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summaries
                        .map((s) => s.replaceFirst(RegExp(r'^이동:\s*'), ''))
                        .join('\n'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (metrics.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map(
                    (w) => SizedBox(
                      width: metrics.length == 1 || box.maxWidth < 240
                          ? box.maxWidth
                          : (box.maxWidth - 12) / 2,
                      child: w,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (info['식사 장소 유형']?.isNotEmpty == true &&
            info['식사 장소 유형'] != '식당') ...[
          Wrap(
            children: [
              Chip(
                avatar: const Icon(Icons.restaurant_rounded, size: 16),
                label: Text(info['식사 장소 유형']!),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        for (final key in ['영업시간', '영업일', '휴무일'])
          if (info[key]?.isNotEmpty == true)
            _InformationRow(
              label: key,
              value: info[key]!,
              icon: key == '영업시간'
                  ? Icons.access_time
                  : Icons.calendar_month_outlined,
            ),
        if (info['숙박요금 비교']?.isNotEmpty == true)
          _Disclosure(
            title: '숙박요금 비교',
            child: _HotelPriceSources(text: info['숙박요금 비교']!),
          ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (description.length > 110 ||
              '\n'.allMatches(description).length > 2)
            _Description(text: description)
          else
            Text(
              description,
              style: const TextStyle(
                height: 1.65,
                color: AppColors.textSecondary,
              ),
            ),
        ],
        if (extra.isNotEmpty)
          _Disclosure(
            title: '방문 정보',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: extra.entries
                  .map(
                    (e) => _InformationRow(
                      label: e.key,
                      value: e.value,
                      icon: e.key == '주소'
                          ? Icons.location_on_outlined
                          : e.key == '전화번호'
                          ? Icons.phone_outlined
                          : Icons.hotel_outlined,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (movement.trim().isNotEmpty ||
            directionsUrl != null ||
            info['공항 내 이동']?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          if (info['공항 내 이동']?.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '공항에서 대중교통으로 이동',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final entry
                      in info['공항 내 이동']!
                          .split('\n')
                          .where((s) => s.trim().isNotEmpty))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _InformationRow(
                        label: entry.contains('→')
                            ? '이동 경로'
                            : entry.startsWith('도보')
                            ? '도보 이동'
                            : entry.endsWith('탑승')
                            ? '탑승 노선'
                            : '안내',
                        value: entry,
                        icon: entry.startsWith('도보')
                            ? Icons.directions_walk
                            : entry.endsWith('탑승')
                            ? Icons.train_outlined
                            : Icons.location_on_outlined,
                      ),
                    ),
                  if (airportAccessUrl != null)
                    TextButton.icon(
                      onPressed: () =>
                          showDirectionsPreview(context, airportAccessUrl!),
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('공항 → 승차 지점 실제 경로 보기'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (details.isNotEmpty)
            _Disclosure(
              title: '이동 상세 보기',
              child: TransportDetails(text: details),
            ),
        ],
        if (directionsUrl != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showDirectionsPreview(
                context,
                directionsUrl!,
                details: movement,
              ),
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('실제 경로 보기'),
            ),
          ),
      ],
    );
  }

  IconData _transportIcon(String text) => text.contains('자동차')
      ? Icons.directions_car_outlined
      : text.contains('지하철') || text.contains('열차') || text.contains('철도')
      ? Icons.train_outlined
      : text.contains('버스')
      ? Icons.directions_bus_outlined
      : Icons.directions_walk;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(value, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.primary),
        ),
        children: [child],
      ),
    ),
  );
}

class _Description extends StatefulWidget {
  const _Description({required this.text});
  final String text;
  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.text,
        maxLines: expanded ? null : 3,
        overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        style: const TextStyle(height: 1.65, color: AppColors.textSecondary),
      ),
      TextButton(
        onPressed: () => setState(() => expanded = !expanded),
        child: Text(expanded ? '설명 접기' : '설명 더 보기'),
      ),
    ],
  );
}

class _HotelPriceSources extends StatelessWidget {
  const _HotelPriceSources({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in text.split('\n\n'))
        Builder(
          builder: (context) {
            final lines = block.split('\n');
            final url = Uri.tryParse(lines.last);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lines.first, style: const TextStyle(height: 1.6)),
                  if (url != null && url.scheme == 'https')
                    TextButton.icon(
                      onPressed: () =>
                          launchUrl(url, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('가격 출처 확인'),
                    ),
                ],
              ),
            );
          },
        ),
    ],
  );
}
