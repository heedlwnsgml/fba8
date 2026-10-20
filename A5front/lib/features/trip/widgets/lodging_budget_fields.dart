import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/state/trip_draft.dart';
import '../../../core/state/money_display.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/network/planner_api.dart';

class LodgingBudgetFields extends StatefulWidget {
  const LodgingBudgetFields({super.key, this.api});
  final PlannerApi? api;
  @override
  State<LodgingBudgetFields> createState() => _LodgingBudgetFieldsState();
}

class _LodgingBudgetFieldsState extends State<LodgingBudgetFields> {
  final d = TripDraft.instance;
  late final controller = TextEditingController(
    text:
        (d.hotelBudgetInput ??
                (d.hotelBudgetCurrency == 'JPY' ? d.hotelBudgetYen : null))
            ?.toString() ??
        '',
  );
  Map<String, dynamic>? rate;
  bool loading = true;
  bool failed = false;
  String get currency => d.hotelBudgetCurrency;
  num? get krwPerJpy => rate?['krwPerJpy'] as num?;
  String money(num amount) => NumberFormat('#,##0').format(amount);
  @override
  void initState() {
    super.initState();
    d.hotelBudgetConversionPending =
        currency == 'KRW' && d.hotelBudgetInput != null;
    loadRate();
  }

  Future<void> loadRate() async {
    try {
      final preferred = await (widget.api ?? PlannerApi.instance)
          .getHotelCurrencyPreference();
      if (!mounted) return;
      (widget.api ?? PlannerApi.instance).money.configure(currency: preferred);
      if (!d.hotelBudgetCurrencyChosen && d.hotelBudgetInput == null) {
        setState(() {
          if (d.hotelBudgetCurrency != preferred) {
            controller.text = preferred == 'JPY'
                ? d.hotelBudgetYen?.toString() ?? ''
                : '';
          }
          d.hotelBudgetCurrency = preferred;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    try {
      final value = await (widget.api ?? PlannerApi.instance).getExchangeRate();
      if (mounted)
        setState(() {
          rate = value;
          (widget.api ?? PlannerApi.instance).money.configure(
            rate: value['krwPerJpy'] as num?,
          );
          failed = false;
          if (currency == 'KRW' &&
              d.hotelBudgetInput == null &&
              d.hotelBudgetYen != null &&
              controller.text.isEmpty) {
            controller.text =
                '${MoneyDisplay.roundWon(d.hotelBudgetYen! * (value['krwPerJpy'] as num))}';
          }
          sync();
        });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void sync() {
    final input = int.tryParse(controller.text);
    d.hotelBudgetInput = input;
    d.hotelBudgetConversionPending =
        currency == 'KRW' && input != null && krwPerJpy == null;
    d.hotelBudgetYen = input == null
        ? null
        : currency == 'JPY'
        ? input
        : krwPerJpy == null
        ? null
        : (input / krwPerJpy!).floor();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('숙소 요금 상한 · 선택', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '숙소 요금만 해당하며, 식비·교통비·관광 비용은 포함하지 않습니다.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'perNight', label: Text('하루 숙박비')),
              ButtonSegment(value: 'total', label: Text('전체 숙박비')),
            ],
            selected: {d.hotelBudgetMode},
            onSelectionChanged: (v) =>
                setState(() => d.hotelBudgetMode = v.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'KRW',
                label: const Text('원 (KRW)'),
                enabled: krwPerJpy != null,
              ),
              const ButtonSegment(value: 'JPY', label: Text('엔 (JPY)')),
            ],
            selected: {currency},
            onSelectionChanged: (v) async {
              if (v.first == 'KRW' && currency != 'KRW') {
                final accepted = await showAppConfirmDialog(
                  context: context,
                  title: '원화 입력으로 변경할까요?',
                  message: MoneyDisplay.roundingNotice,
                  confirmText: '변경',
                );
                if (!mounted || !accepted) return;
              }
              setState(() {
                final yen = d.hotelBudgetYen;
                d.hotelBudgetCurrencyChosen = true;
                d.hotelBudgetCurrency = v.first;
                controller.text = yen == null
                    ? ''
                    : currency == 'JPY'
                    ? '$yen'
                    : '${MoneyDisplay.roundWon(yen * krwPerJpy!)}';
                sync();
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: d.hotelBudgetMode == 'perNight'
                  ? '1박 숙소 요금'
                  : '전체 숙박비',
              suffixText: currency == 'JPY' ? '엔' : '원',
              hintText: '금액 입력 · 선택 사항',
              helperText: '미기입 시 숙소 요금 제한 없이 일정을 생성합니다.',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(sync),
          ),
          if (d.hotelBudgetYen != null && krwPerJpy != null) ...[
            const SizedBox(height: 10),
            Text(
              '숙소 예산: ${(widget.api ?? PlannerApi.instance).money.yen(d.hotelBudgetYen!)}',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (rate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '1엔 = ${krwPerJpy!.toStringAsFixed(2)}원',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (failed)
            TextButton(onPressed: loadRate, child: const Text('환율 다시 불러오기')),
          const SizedBox(height: 8),
          const Text(MoneyDisplay.roundingNotice),
          const SizedBox(height: 8),
          const Text(
            '등록된 평균 숙박요금으로 비교합니다. 실제 예약 요금과 환전 수수료에 따라 금액이 달라질 수 있습니다.',
          ),
        ],
      ),
    ),
  );
}
