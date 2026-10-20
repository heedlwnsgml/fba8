import 'package:flutter/material.dart';
import '../../../core/network/planner_api.dart';
import '../../../core/state/money_display.dart';
import '../../../core/widgets/app_confirm_dialog.dart';

class HotelCurrencyPreferenceCard extends StatefulWidget {
  const HotelCurrencyPreferenceCard({super.key, required this.api});
  final PlannerApi api;
  @override
  State<HotelCurrencyPreferenceCard> createState() =>
      _HotelCurrencyPreferenceCardState();
}

class _HotelCurrencyPreferenceCardState
    extends State<HotelCurrencyPreferenceCard> {
  String currency = 'KRW';
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = await widget.api.getHotelCurrencyPreference();
      if (mounted)
        setState(() {
          currency = result;
          widget.api.money.configure(currency: result);
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = '기본 통화를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(String value) async {
    if (value == currency) return;
    if (value == 'KRW') {
      final accepted = await showAppConfirmDialog(
        context: context,
        title: '원화로 표시할까요?',
        message: MoneyDisplay.roundingNotice,
        confirmText: '원화로 변경',
      );
      if (!mounted || !accepted) return;
    }
    final previous = currency;
    setState(() {
      currency = value;
      busy = true;
      error = null;
    });
    try {
      await widget.api.saveHotelCurrencyPreference(value);
      widget.api.money.configure(currency: value);
    } catch (_) {
      if (mounted)
        setState(() {
          currency = previous;
          error = '저장하지 못했습니다. 다시 선택해 주세요.';
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '금액 표시 통화',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '숙소 요금·교통비·국내선 항공료·패스와 PDF의 금액에 적용됩니다.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(MoneyDisplay.roundingNotice),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'KRW', label: Text('원 (KRW)')),
              ButtonSegment(value: 'JPY', label: Text('엔 (JPY)')),
            ],
            selected: {currency},
            onSelectionChanged: busy ? null : (s) => save(s.first),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!),
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
