import 'package:flutter/material.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/state/trip_draft.dart';

class LongTripSettingsCard extends StatefulWidget {
  const LongTripSettingsCard({super.key, required this.api});
  final PlannerApi api;
  @override
  State<LongTripSettingsCard> createState() => _LongTripSettingsCardState();
}

class _LongTripSettingsCardState extends State<LongTripSettingsCard> {
  Map<String, dynamic>? values;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.getLongTripSettings();
      for (final field in [
        'liveRestEveryDays',
        'liveRestSightHours',
        'tourLightEveryDays',
        'tourLightSightHours',
      ]) {
        if (result[field] is! num)
          throw const FormatException('Invalid long trip settings');
      }
      if (mounted) setState(() => values = result);
    } catch (_) {
      if (mounted) setState(() => error = '장기 일정 설정을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.updateLongTripSettings({
        ...values!,
        'liveRestEveryDays': values!['tourLightEveryDays'],
        'liveRestSightHours': values!['tourLightSightHours'],
      });
      if (!mounted) return;
      setState(() => values = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장기 일정 기본 설정을 저장했습니다.')));
    } catch (_) {
      if (mounted) setState(() => error = '저장하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget setting(String title, String every, String hours) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: (values![every] as num).toInt(),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '여유일 간격',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('없음')),
                  for (int n = 2; n <= 30; n++)
                    DropdownMenuItem(value: n, child: Text('$n일마다')),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => values![every] = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: (values![hours] as num).toDouble(),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '관광시간 상한',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int n = 0; n <= 20; n++)
                    DropdownMenuItem(
                      value: n / 2,
                      child: Text(
                        n == 0 ? '관광 안 함' : '${n.isEven ? n ~/ 2 : n / 2}시간',
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => values![hours] = v),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '장기 일정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '15일 이상 여행의 여유일을 설정합니다. 저장한 기본값은 다음 일정 생성부터 적용되며, 생성할 때도 켜거나 끌 수 있습니다.',
            style: TextStyle(height: 1.5),
          ),
          if (values != null) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('여유일 기본 사용'),
              value: values!['restDaysEnabled'] != false,
              onChanged: busy
                  ? null
                  : (v) => setState(() => values!['restDaysEnabled'] = v),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: values!['restDaysEnabled'] == false
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        setting(
                          '여유일 설정',
                          'tourLightEveryDays',
                          'tourLightSightHours',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '관광시간은 관광지 체류시간의 합계이며 식사·카페·이동은 제외합니다. 첫날·마지막 날과 고정 일정이 있는 날에는 여유일을 배치하지 않습니다.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: const Text('기본 설정 저장'),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            if (values == null)
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('다시 불러오기'),
              ),
          ],
        ],
      ),
    ),
  );
}

class TripRestDaysToggle extends StatefulWidget {
  const TripRestDaysToggle({super.key, this.api});
  final PlannerApi? api;
  @override
  State<TripRestDaysToggle> createState() => _TripRestDaysToggleState();
}

class _TripRestDaysToggleState extends State<TripRestDaysToggle> {
  bool? defaultEnabled;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final v = await (widget.api ?? PlannerApi.instance).getLongTripSettings();
      if (mounted)
        setState(() {
          defaultEnabled = v['restDaysEnabled'] != false;
          failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        SwitchListTile.adaptive(
          title: const Text('여유일 사용'),
          subtitle: Text(
            failed
                ? '기본 설정을 불러오지 못했습니다. 직접 선택하거나 다시 불러오세요.'
                : '이번 여행에만 적용합니다. 15일 이상 여행은 마이페이지의 간격·관광시간을 사용합니다.',
          ),
          value: TripDraft.instance.restDaysEnabled ?? defaultEnabled ?? true,
          onChanged: (v) =>
              setState(() => TripDraft.instance.restDaysEnabled = v),
        ),
        if (defaultEnabled == null && !failed) const LinearProgressIndicator(),
        if (failed)
          TextButton(onPressed: load, child: const Text('기본 설정 다시 불러오기')),
      ],
    ),
  );
}
